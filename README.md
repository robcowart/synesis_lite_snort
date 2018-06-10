# sýnesis&trade; Lite for Snort
sýnesis&trade; Lite for Snort provides basic analytics for Snort IDS/IPS alert logs using the Elastic Stack.

![synlite_snort](https://user-images.githubusercontent.com/10326954/41204040-c1188290-6cdf-11e8-9711-9c2f8ddba5f4.png)

# Getting Started
sýnesis&trade; Lite for Snort is built using the Elastic Stack, including Elasticsearch, Logstash and Kibana. To install and configure sýnesis&trade; Lite for Snort, you must first have a working Elastic Stack environment. The latest release requires Elastic Stack version 6.2 or later.

Refer to the following compatibility chart to choose a release of sýnesis&trade; Lite for Snort that is compatible with the version of the Elastic Stack you are using.

Elastic Stack |  v1.x
:---:|:---:
6.2 | &#10003;

## Setting up Elasticsearch
Currently there is no specific configuration required for Elasticsearch. As long as Kibana and Logstash can talk to your Elasticsearch cluster you should be ready to go. The index template required by Elasticsearch will be uploaded by Logstash.

At high ingest rates (>5K logs/s), or for data redundancy and high availability, a multi-node cluster is recommended.

## Filebeat
As Snort is usually run on one or more Linux servers, the solution includes both [Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-overview.html) and [Logstash](https://www.elastic.co/guide/en/logstash/current/introduction.html). Filebeat is used to collect the log data on the system where Snort is running, and ships it to Logstash via the Beats input. An example Filebeat prospector configuration is included in `filebeat/filebeat.yml`.

## Setting up Logstash
The sýnesis&trade; Lite for Snort Logstash pipeline is the heart of the solution. It is here that the raw flow data is collected, decoded, parsed, formatted and enriched. It is this processing that makes possible the analytics options provided by the Kibana [dashboards](#dashboards).

Follow these steps to ensure that Logstash and sýnesis&trade; Lite for Snort are optimally configured to meet your needs. 

### 1. Set JVM heap size.
To increase performance, sýnesis&trade; Lite for Snort takes advantage of the caching and queueing features available in many of the Logstash plugins. These features increase the consumption of the JVM heap. The JVM heap space used by Logstash is configured in `jvm.options`. It is recommended that Logstash be given at least 2GB of JVM heap. This is configured in `jvm.options` as follows:

```
-Xms2g
-Xmx2g
```

### 2. Add and Update Required Logstash plugins
It is also recommended that you always use the latest version of the [DNS](https://www.elastic.co/guide/en/logstash/current/plugins-filters-dns.html) filter. This can achieved by running the following command:

```
LS_HOME/bin/logstash-plugin update logstash-filter-dns
```

### 3. Copy the pipeline files to the Logstash configuration path.
There are four sets of configuration files provided within the `logstash/synlite_snort` folder:
```
logstash
  `- synlite_snort
       |- conf.d  (contains the logstash pipeline)
       |- dictionaries (yaml files used to enrich the raw log data)
       |- geoipdbs  (contains GeoIP databases)
       `- templates  (contains index templates)
```

Copy the `synlite_snort` directory to the location of your Logstash configuration files (e.g. on RedHat/CentOS or Ubuntu this would be `/etc/logstash/synlite_snort` ). If you place the pipeline within a different path, you will need to modify the following environment variables to specify the correct location:

Environment Variable | Description | Default Value
--- | --- | ---
SYNLITE_SNORT_DICT_PATH | The path where the dictionary files are located | /etc/logstash/synlite_snort/dictionaries
SYNLITE_SNORT_TEMPLATE_PATH | The path to where index templates are located | /etc/logstash/synlite_snort/templates
SYNLITE_SNORT_GEOIP_DB_PATH | The path where the GeoIP DBs are located | /etc/logstash/synlite_snort/geoipdbs

### 4. Setup environment variable helper files
Rather than directly editing the pipeline configuration files for your environment, environment variables are used to provide a single location for most configuration options. These environment variables will be referred to in the remaining instructions. A [reference](#environment-variable-reference) of all environment variables can be found [here](#environment-variable-reference).

Depending on your environment there may be many ways to define environment variables. The files `profile.d/synlite_snort.sh` and `logstash.service.d/synlite_snort.conf` are provided to help you with this setup.

Recent versions of both RedHat/CentOS and Ubuntu use systemd to start background processes. When deploying sýnesis&trade; Lite for Snort on a host where Logstash will be managed by systemd, copy `logstash.service.d/synlite_snort.conf` to `/etc/systemd/system/logstash.service.d/synlite_snort.conf`. Any configuration changes can then be made by editing this file.

> Remember that for your changes to take effect, you must issue the command `sudo systemctl daemon-reload`.

### 5. Add the sýnesis&trade; Lite for Snort pipeline to pipelines.yml
Logstash 6.0 introduced the ability to run multiple pipelines from a single Logstash instance. The `pipelines.yml` file is where these pipelines are configured. While a single pipeline can be specified directly in `logstash.yml`, it is a good practice to use `pipelines.yml` for consistency across environments.

Edit `pipelines.yml` (usually located at `/etc/logstash/pipelines.yml`) and add the sýnesis&trade; Lite for Snort pipeline (adjust the path as necessary).

```
- pipeline.id: synlite_snort
  path.config: "/etc/logstash/synlite_snort/conf.d/*.conf"
```

### 6. Configure inputs
By default Filebeat data will be recieved on all IPv4 addresses of the Logstash host using the default TCP port 5044. You can change both the IP and port used by modifying the following environment variables:

Environment Variable | Description | Default Value
--- | --- | ---
SYNLITE_SNORT_BEATS_HOST | The IP address on which to listen for Filebeat messages | 0.0.0.0
SYNLITE_SNORT_BEATS_PORT | The TCP port on which to listen for Filebeat messages | 5044

### 7. Configure Elasticsearch output
Obviously the data needs to land in Elasticsearch, so you need to tell Logstash where to send it. This is done by setting these environment variables:

Environment Variable | Description | Default Value
--- | --- | ---
SYNLITE_SNORT_ES_HOST | The Elasticsearch host to which the output will send data | 127.0.0.1:9200
SYNLITE_SNORT_ES_USER | The password for the connection to Elasticsearch | elastic
SYNLITE_SNORT_ES_PASSWD | The username for the connection to Elasticsearch | changeme

> If you are only using the open-source version of Elasticsearch, it will ignore the username and password. In that case just leave the defaults.

### 8. Enable DNS name resolution (optional)
In the past it was recommended to avoid DNS queries as the latency costs of such lookups had a devastating effect on throughput. While the Logstash DNS filter provides a caching mechanism, its use was not recommended. When the cache was enabled all lookups were performed synchronously. If a name server failed to respond, all other queries were stuck waiting until the query timed out. The end result was even worse performance.

Fortunately these problems have been resolved. Release 3.0.8 of the DNS filter introduced an enhancement which caches timeouts as failures, in addition to normal NXDOMAIN responses. This was an important step as many domain owner intentionally setup their nameservers to ignore the reverse lookups needed to enrich flow data. In addition to this change, I submitted am enhancement which allows for concurrent queries when caching is enabled. The Logstash team approved this change, and it is included in 3.0.10 of the plugin.

With these changes I can finally give the green light for using DNS lookups to enrich the incoming data. You will see a little slow down in throughput until the cache warms up, but that usually lasts only a few minutes. Once the cache is warmed up, the overhead is minimal, and event rates averaging 10K/s and as high as 40K/s were observed in testing.

The key to good performance is setting up the cache appropriately. Most likely it will be DNS timeouts that are the source of most latency. So ensuring that a higher volume of such misses can be cached for longer periods of time is most important.

The DNS lookup features of sýnesis&trade; Lite for Snort can be configured using the following environment variables:

Environment Variable | Description | Default Value
--- | --- | ---
SYNLITE_SNORT_RESOLVE_IP2HOST | Enable/Disable DNS requests | false
SYNLITE_SNORT_NAMESERVER | The DNS server to which the dns filter should send requests | 127.0.0.1
SYNLITE_SNORT_DNS_HIT_CACHE_SIZE | The cache size for successful DNS queries | 25000
SYNLITE_SNORT_DNS_HIT_CACHE_TTL | The time in seconds successful DNS queries are cached | 900
SYNLITE_SNORT_DNS_FAILED_CACHE_SIZE | The cache size for failed DNS queries | 75000
SYNLITE_SNORT_DNS_FAILED_CACHE_TTL | The time in seconds failed DNS queries are cached | 3600

### 9. Start Logstash
You should now be able to start Logstash and begin collecting network flow data. Assuming you are running a recent version of RedHat/CentOS or Ubuntu, and using systemd, complete these steps:
1. Run `systemctl daemon-reload` to ensure any changes to the environment variables are recognized.
2. Run `systemctl start logstash`
> NOTICE! Make sure that you have already setup the Logstash init files by running `LS_HOME/bin/system-install`. If the init files have not been setup you will receive an error.
To follow along as Logstash starts you can tail its log by running:

```
tail -f /var/log/logstash/logstash-plain.log
```
Logstash takes a little time to start... BE PATIENT!

Logstash setup is now complete. If you are receiving data from Filebeat, you should have `snort-` daily indices in Elasticsearch.

## Setting up Kibana
An API (yet undocumented) is available to import and export Index Patterns. The JSON files which contains the Index Pattern configurations are `synlite_snort.index_pattern.json` and `synlite_snort_stats.index_pattern.json`. To setup the Index Patterns run the following commands:

```
curl -X POST -u USERNAME:PASSWORD http://KIBANASERVER:5601/api/saved_objects/index-pattern/snort-* -H "Content-Type: application/json" -H "kbn-xsrf: true" -d @/PATH/TO/synlite_snort.index_pattern.json
```

Finally the vizualizations and dashboards can be loaded into Kibana by importing the `synlite_snort.dashboards.json` file from within the Kibana UI. This is done in the Kibana `Management` app under `Saved Objects`.

### Recommended Kibana Advanced Settings
You may find that modifying a few of the Kibana advanced settings will produce a more user-friendly experience while using sýnesis&trade; Lite for Snort . These settings are made in Kibana, under `Management -> Advanced Settings`.

Advanced Setting | Value | Why make the change?
--- | --- | ---
doc_table:highlight | false | There is a pretty big query performance penalty that comes with using the highlighting feature. As it isn't very useful for this use-case, it is better to just trun it off.
filters:pinnedByDefault | true | Pinning a filter will it allow it to persist when you are changing dashbaords. This is very useful when drill-down into something of interest and you want to change dashboards for a different perspective of the same data. This is the first setting I change whenever I am working with Kibana.
state:storeInSessionStorage | true | Kibana URLs can get pretty large. Especially when working with Vega visualizations. This will likely result in error messages for users of Internet Explorer. Using in-session storage will fix this issue for these users.
timepicker:quickRanges | [see below](#recommended-setting-for-timepicker:quickRanges) | The default options in the Time Picker are less than optimal, for most logging and monitoring use-cases. Fortunately Kibana no allows you to customize the time picker. Our recommended settings can be found [see below](#recommended-setting-for-timepicker:quickRanges).

## Dashboards
The following dashboards are provided.

> NOTE: The dashboards are optimized for a monitor resolution of 1920x1080.

### Alerts
![snort_alerts](https://user-images.githubusercontent.com/10326954/41203870-8a88f6bc-6cdd-11e8-86df-2158172be3e3.png)

### Threats - Public Attackers
![snort_threats_public_attackers](https://user-images.githubusercontent.com/10326954/41203876-8b44ff4c-6cdd-11e8-99ef-4f303d56675c.png)

### Threats - At-Risk Servers
![snort_threats_risk_servers](https://user-images.githubusercontent.com/10326954/41203901-d341d1d0-6cdd-11e8-9dc4-8bef35760f8d.png)

### Threats - At-Risk Services
![snort_threats_risk_services](https://user-images.githubusercontent.com/10326954/41203878-8ba7bb1e-6cdd-11e8-92d5-bd310e0e9d99.png)

### Threats - High-Risk Clients
![snort_threats_risk_clients](https://user-images.githubusercontent.com/10326954/41203877-8b74899c-6cdd-11e8-90da-e7ca78917834.png)

### Sankey
![snort_sankey](https://user-images.githubusercontent.com/10326954/41203875-8b16ca8c-6cdd-11e8-9f3b-67ffdaef3809.png)

### Geo IP
![snort_geoip](https://user-images.githubusercontent.com/10326954/41203872-8ab6d0c8-6cdd-11e8-9ba2-f3c300771237.png)

### Raw Logs
![snort_raw_logs](https://user-images.githubusercontent.com/10326954/41203874-8ae4ead0-6cdd-11e8-8962-b5c6b92d3067.png)

# Environment Variable Reference
The supported environment variables are:

Environment Variable | Description | Default Value
--- | --- | ---
SYNLITE_SNORT_DICT_PATH | The path where the dictionary files are located | /etc/logstash/synlite_snort/dictionaries
SYNLITE_SNORT_TEMPLATE_PATH | The path to where index templates are located | /etc/logstash/synlite_snort/templates
SYNLITE_SNORT_GEOIP_DB_PATH | The path where the GeoIP DBs are located | /etc/logstash/synlite_snort/geoipdbs
SYNLITE_SNORT_GEOIP_CACHE_SIZE | The size of the GeoIP query cache | 8192
SYNLITE_SNORT_GEOIP_LOOKUP | Enable/Disable GeoIP lookups | true
SYNLITE_SNORT_ASN_LOOKUP | Enable/Disable ASN lookups | true
SYNLITE_SNORT_CLEANUP_SIGS | Enable this option to remove unneeded text from alert signatures. | false
SYNLITE_SNORT_RESOLVE_IP2HOST | Enable/Disable DNS requests | false
SYNLITE_SNORT_NAMESERVER | The DNS server to which the dns filter should send requests | 127.0.0.1
SYNLITE_SNORT_DNS_HIT_CACHE_SIZE | The cache size for successful DNS queries | 25000
SYNLITE_SNORT_DNS_HIT_CACHE_TTL | The time in seconds successful DNS queries are cached | 900
SYNLITE_SNORT_DNS_FAILED_CACHE_SIZE | The cache size for failed DNS queries | 75000
SYNLITE_SNORT_DNS_FAILED_CACHE_TTL | The time in seconds failed DNS queries are cached | 3600
SYNLITE_SNORT_ES_HOST | The Elasticsearch host to which the output will send data | 127.0.0.1:9200
SYNLITE_SNORT_ES_USER | The password for the connection to Elasticsearch | elastic
SYNLITE_SNORT_ES_PASSWD | The username for the connection to Elasticsearch | changeme
SYNLITE_SNORT_BEATS_HOST | The IP address on which to listen for Filebeat messages | 0.0.0.0
SYNLITE_SNORT_BEATS_PORT | The TCP port on which to listen for Filebeat messages | 5044

# Recommended Setting for timepicker:quickRanges
I recommend configuring `timepicker:quickRanges` for the setting below. The result will look like this:

![screen shot 2018-05-17 at 19 57 03](https://user-images.githubusercontent.com/10326954/40195016-8d33cac4-5a0c-11e8-976f-cc6559e4439a.png)

```
[
  {
    "from": "now/d",
    "to": "now/d",
    "display": "Today",
    "section": 0
  },
  {
    "from": "now/w",
    "to": "now/w",
    "display": "This week",
    "section": 0
  },
  {
    "from": "now/M",
    "to": "now/M",
    "display": "This month",
    "section": 0
  },
  {
    "from": "now/d",
    "to": "now",
    "display": "Today so far",
    "section": 0
  },
  {
    "from": "now/w",
    "to": "now",
    "display": "Week to date",
    "section": 0
  },
  {
    "from": "now/M",
    "to": "now",
    "display": "Month to date",
    "section": 0
  },
  {
    "from": "now-15m",
    "to": "now",
    "display": "Last 15 minutes",
    "section": 1
  },
  {
    "from": "now-30m",
    "to": "now",
    "display": "Last 30 minutes",
    "section": 1
  },
  {
    "from": "now-1h",
    "to": "now",
    "display": "Last 1 hour",
    "section": 1
  },
  {
    "from": "now-2h",
    "to": "now",
    "display": "Last 2 hours",
    "section": 1
  },
  {
    "from": "now-4h",
    "to": "now",
    "display": "Last 4 hours",
    "section": 2
  },
  {
    "from": "now-12h",
    "to": "now",
    "display": "Last 12 hours",
    "section": 2
  },
  {
    "from": "now-24h",
    "to": "now",
    "display": "Last 24 hours",
    "section": 2
  },
  {
    "from": "now-48h",
    "to": "now",
    "display": "Last 48 hours",
    "section": 2
  },
  {
    "from": "now-7d",
    "to": "now",
    "display": "Last 7 days",
    "section": 3
  },
  {
    "from": "now-30d",
    "to": "now",
    "display": "Last 30 days",
    "section": 3
  },
  {
    "from": "now-60d",
    "to": "now",
    "display": "Last 60 days",
    "section": 3
  },
  {
    "from": "now-90d",
    "to": "now",
    "display": "Last 90 days",
    "section": 3
  }
]
```

# Attribution
This product includes GeoLite data created by MaxMind, available from (http://www.maxmind.com)
