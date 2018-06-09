#------------------------------------------------------------------------------
# Copyright (C)2018 Robert Cowart
# 
# The contents of this file and/or repository are subject to the Robert Cowart
# Public License (the "License") and may not be used or distributed except in
# compliance with the License. You may obtain a copy of the License at:
# 
# http://www.koiossian.com/public/robert_cowart_public_license.txt
# 
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
# the specific language governing rights and limitations under the License.
# 
# The Original Source Code was developed by Robert Cowart. Portions created by
# Robert Cowart are Copyright (C)2018 Robert Cowart. All Rights Reserved.
#------------------------------------------------------------------------------

# Synesis Lite for Snort global configuration
export SYNLITE_SNORT_DICT_PATH=/etc/logstash/synlite_snort/dictionaries
export SYNLITE_SNORT_TEMPLATE_PATH=/etc/logstash/synlite_snort/templates
export SYNLITE_SNORT_GEOIP_DB_PATH=/etc/logstash/synlite_snort/geoipdbs
export SYNLITE_SNORT_GEOIP_CACHE_SIZE=8192
export SYNLITE_SNORT_GEOIP_LOOKUP=true
export SYNLITE_SNORT_ASN_LOOKUP=true
export SYNLITE_SNORT_CLEANUP_SIGS=false

# Name resolution option
export SYNLITE_SNORT_RESOLVE_IP2HOST=false
export SYNLITE_SNORT_NAMESERVER=127.0.0.1
export SYNLITE_SNORT_DNS_HIT_CACHE_SIZE=25000
export SYNLITE_SNORT_DNS_HIT_CACHE_TTL=900
export SYNLITE_SNORT_DNS_FAILED_CACHE_SIZE=75000
export SYNLITE_SNORT_DNS_FAILED_CACHE_TTL=3600

# Elasticsearch connection settings
export SYNLITE_SNORT_ES_HOST=127.0.0.1
export SYNLITE_SNORT_ES_USER=elastic
export SYNLITE_SNORT_ES_PASSWD=changeme

# Beats input
export SYNLITE_SNORT_BEATS_HOST=0.0.0.0
export SYNLITE_SNORT_BEATS_PORT=5044
