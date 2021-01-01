import boto3
import json
import ldap3
import os
import time


# Default varibles
default_region = 'us-east-1'
default_join_document = 'AWS-JoinDirectoryServiceDomain'
default_base_dn = "CN=Computers,DC=example,DC=com"
default_secretmanager_path = 'aws/directory-services/{}/seamless-domain-join'
tags_prefix = 'Domain:'

def getDsRegion():
    # Return region configured via Environment variable otherwise return current region
    try:
        return os.environ.get('ds_region', os.environ['AWS_REGION'])
    except:
        return default_region

def collect_ds_information(directoryId):
    # Open Boto3 client to region of Directory
    ds = boto3.client('ds', region_name=getDsRegion())

    # Describe given directory
    # https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ds.html#DirectoryService.Client.describe_directories
    dss = ds.describe_directories(
        DirectoryIds = [
            directoryId
        ]
    ).get('DirectoryDescriptions', [])
    
    # return descriptor
    return len(dss) and dss[0] or None

def get_join_document():
    return os.environ.get('join_document', default_join_document)

def get_instance_id(event):
    return event['detail']['instance-id']

def get_directory_id():
    return os.environ['directoryId']

def get_basedn():
    return os.environ.get('directoryOU', default_base_dn)

def get_proto():
    return os.environ.get('proto', 'ldap').strip()

def get_ldap_host(fallback):
    ldap_host = os.environ.get('ldap_host', None)
    if ldap_host and ldap_host.strip() != "":
        return ldap_host.strip()
    return fallback.strip()

def get_directory_credentials(directory_id, domain_name):

    # Define path
    path = default_secretmanager_path.format(directory_id) 

    # Retrieve credentials
    sm = boto3.client('secretsmanager', region_name=getDsRegion())
    from pprint import pprint
    secret = json.loads(sm.get_secret_value(
        SecretId = path
    )['SecretString'])

    # Format for login
    return {
        'user': '{}@{}'.format(secret['awsSeamlessDomainUsername'], domain_name),
        'password': secret['awsSeamlessDomainPassword']
    }

def delete_from_ldap(conn, basedn, entry, instance_id):
    i = 0
    while True:
        # Delete item from LDAP
        conn.delete(entry.entry_dn)
        
        # Test proper deletion
        time.sleep(5)
        searchState = conn.search(basedn,"(description={})".format(instance_id))
        if not searchState or len(conn.entries) <= 0:
            break
        
        # Fallback
        i+=1
        if i > 3:
            print("! Unable to delete from LDAP")
            break

        # Seems the item stayed in LDAP, so waiting
        print('.',)
        time.sleep(25)

# Lambda function
def handle_ec2_change(event, context):
    # Filter out missleading events
    if not event['detail']['state'] in ['pending', 'terminated'] :
        return json.dumps({'status': 'error'})

    # Initial print
    print("Working on instance {} - {}".format(get_instance_id(event), event['detail']['state']))

    # Populate common variables
    directory_id = get_directory_id()
    desc = collect_ds_information(directory_id)    
    if not desc:
        print('There is no such a directory {}'.format(directory_id))
        return

    basedn = get_basedn()
    print("* Dealing with {}".format(basedn))
    domain_name = desc['Name']
    dns_servers = desc['DnsIpAddrs']

    # Open connection Active Directory
    server = ldap3.Server('{}://{}'.format(get_proto(), get_ldap_host(domain_name)))
    conn = ldap3.Connection(server, **get_directory_credentials(directory_id, domain_name))
    if not conn.bind():
        print('error in bind', conn.result)

    # Search for EC2 instances
    searchState = conn.search(basedn,"(description={})".format(get_instance_id(event)))
    print("* LDAP search status {}: {}".format(searchState, len(conn.entries)))

    # * Pending
    # Validate whether EC2 is in AD already
    # Register trigger SSM document against server
    if event['detail']['state'] == 'pending':
        # Describe instance to find all tags

        # No instance were found
        if not searchState or len(conn.entries) == 0:
            # Validate the server should be joined
            print("* Describing EC2 instance {}".format(get_instance_id(event)))
            ec2 = boto3.client('ec2', region_name=event['region'])
            ds = ec2.describe_instances(
                InstanceIds = [
                    get_instance_id(event)
                ]
            )
            instances = [item for sublist in ds.get('Reservations', []) for item in sublist['Instances']]
            fins = [x for x in instances if x['InstanceId'] == get_instance_id(event)]
            if len(fins) <= 0:
                return json.dumps({'status': 'no such instances'})
            tags = {x['Key'].strip().lower(): x['Value'].strip() for x in fins[0].get('Tags', []) if tags_prefix.lower() in x['Key'].lower()}

            # Determine whether to join or not
            join_domain = tags.get('domain:join', 'false').lower() in ['true', '1', 't', 'y', 'yes', 'yeah', 'yup', 'certainly', 'uh-huh']

            # 
            print("* Server is designated for joining to domain: {}".format(join_domain))
            if not join_domain:
                return json.dumps({'status': 'ok'})
            
            # Run SSM Document
            print('* Initiating join {} for instance {}'.format(get_join_document(), get_instance_id(event)))
            ssm = boto3.client('ssm', region_name=event['region'])
            ass = ssm.create_association(
                Name = get_join_document(),
                Targets = [
                    {
                        'Key': 'InstanceIds',
                        'Values': [ get_instance_id(event) ]
                    }
                ],
                Parameters = {
                    'directoryId': [directory_id],
                    'directoryName': [domain_name],
                    'directoryOU': [basedn],
                    'dnsIpAddresses': [ ' '.join(dns_servers) ]
                }
            )
            print(ass)

    # * Termination
    # Remove from AD
    # Remove from Monitoring
    if event['detail']['state'] == 'terminated':

        # Delete From Active directory
        if searchState or len(conn.entries) > 0:
            print('Dropping following DNs:')
            for r in list(conn.entries):
                print(r.entry_dn)
                
                # Delete entry from LDAP
                delete_from_ldap(conn, basedn, r, get_instance_id(event))

    # Dummy return
    return json.dumps({'status': 'ok'})


def handle_cron_cleaning(event, context):
    print("* Look for old computers")
    
    # Collect information about current EC2 instances
    ec2 = boto3.client('ec2', region_name=event['region'])
    instance_ids, d = [], {}
    while True:
        # Collect instance_ids
        descr = ec2.describe_instances(**d)
        instance_ids += [x['InstanceId'] for y in descr['Reservations'] for x in y['Instances']]

        # Pagination
        if "NextToken" in descr:
            d['NextToken'] = descr['NextToken']
            continue
        break

    # Scan for registered instances 
    directory_id = get_directory_id()
    desc = collect_ds_information(directory_id)    
    if not desc:
        print('There is no such a directory {}'.format(directory_id))
        return
    basedn = get_basedn()
    print("* Scanning {}".format(basedn))
    domain_name = desc['Name']

    # Open connection to Active Directory
    server = ldap3.Server('{}://{}'.format(get_proto(), get_ldap_host(domain_name)))
    conn = ldap3.Connection(server, **get_directory_credentials(directory_id, domain_name))
    if not conn.bind():
        print('error in bind', conn.result)

    # Search for EC2 instances
    searchState = conn.search(basedn, "(description=*)", attributes=['description'])
    print("* LDAP search status {}: {}".format(searchState, len(conn.entries)-1))
    # print(instance_ids)
    for s in conn.entries:
        if basedn == s.entry_dn: continue
        # print(s.entry_attributes_as_dict['description'][0], s.entry_attributes_as_dict['description'][0] in instance_ids)
        to_delete = not s.entry_attributes_as_dict['description'][0] in instance_ids
        print("* Entry {} should be deleted (no ec2 exists) {}".format(s.entry_dn, to_delete))
        if to_delete:
            # Delete computer from LDAP
            delete_from_ldap(conn, basedn, s, s.entry_attributes_as_dict['description'][0])


def lambda_handler(event, context):
    # Event print
    print(json.dumps(event))

    # Handler
    if event['source'] == 'aws.ec2':
        return handle_ec2_change(event, context)
    if event['source'] == 'aws.events':
        return handle_cron_cleaning(event, context)
    return json.dumps({'status': 'error'})
    