#!/bin/bash
set -e

YEAR=$1
reyear='^[0-9]+$'
if [ -z "$YEAR" ] || [[ ! $YEAR =~ $reyear ]]; then
  echo "You must provide a numeric year value as the parameter to this script"
  exit -1
fi

work_dir=../temp
mkdir -p $work_dir
manifest_path=$work_dir/manifest.yaml

curl -s "https://raw.githubusercontent.com/devopsdays/devopsdays-web/main/data/events/$YEAR-boston.yml" -o "$manifest_path"

DATA_PATH=../_data/s-$YEAR-speakers.yaml

echo "items: []" > $DATA_PATH
INDEX=0

function trim() {
  local ret=`echo $1 | sed -e 's/^[[:space:]]*//'`
  echo "$ret"
}

person_ids=$(yq eval -j '.program' $manifest_path | jq --raw-output '.[] | select(.type=="talk") | .title')
for ID in $person_ids; do
    echo ID:$ID
    talk_date=$(yq eval --unwrapScalar ".program | .[] | select(.title==\"$ID\") | .date" $manifest_path)
    talk_start_time=$(yq eval --unwrapScalar ".program | .[] | select(.title==\"$ID\") | .start_time" $manifest_path)
    talk_end_time=$(yq eval --unwrapScalar ".program | .[] | select(.title==\"$ID\") | .end_time" $manifest_path)
    speaker_info_raw=$(curl -s "https://raw.githubusercontent.com/devopsdays/devopsdays-web/main/content/events/$YEAR-boston/speakers/$ID.md")
    speaker_bio=$(printf "$speaker_info_raw" | awk -v RS='^$' -v FS='\\+\\+\\+' '{ n = split($0, a); print a[3] }')
    speaker_bio=$(trim "$speaker_bio")
    speaker_meta=$(printf "$speaker_info_raw" | awk -v RS='^$' -v FS='\\+\\+\\+' '{ n = split($0, a); print a[2] }')
    speaker_fullname=$(printf "$speaker_meta" | awk -v RS='^$' -v FS='\n' '{ split($0, lines); for ( line in lines ) { split($line,nvp," = ");
        if (nvp[1] ~ /Title*/) { sep = ""; for (i = 2; i <= length(nvp); i++) { print sep; print nvp[i]; sep = ": "; } }
    }}' | sed -e 's/^"//' -e 's/"$//')
    speaker_fullname=$(trim "$speaker_fullname")
    speaker_twitter=$(printf "$speaker_meta" | awk -v RS='^$' -v FS='\n' '{ split($0, lines); for ( line in lines ) { split($line,nvp," = ");
        if (nvp[1] ~ /twitter*/) { sep = ""; for (i = 2; i <= length(nvp); i++) { print sep; print nvp[i]; sep = ": "; } }
    }}' | sed -e 's/^"//' -e 's/"$//')
    speaker_website=$(printf "$speaker_meta" | awk -v RS='^$' -v FS='\n' '{ split($0, lines); for ( line in lines ) { split($line,nvp," = ");
        if (nvp[1] ~ /website*/) { sep = ""; for (i = 2; i <= length(nvp); i++) { print sep; print nvp[i]; sep = ": "; } }
    }}' | sed -e 's/^"//' -e 's/"$//')
    speaker_talk_raw=$(curl -s "https://raw.githubusercontent.com/devopsdays/devopsdays-web/main/content/events/$YEAR-boston/program/$ID.md")
    speaker_title=$(echo "$speaker_talk_raw" | awk -v RS='^$' -v FS='\n' '{ split($0, lines); for ( line in lines ) { split($line,nvp,": ");
          if (nvp[1] ~ /title*/) { sep = ""; for (i = 2; i <= length(nvp); i++) { print sep; print nvp[i]; sep = ": "; } }
    }}' | sed -e 's/^"//' -e 's/"$//')
    speaker_title=$(trim "$speaker_title")
    speaker_abstract=$(echo "$speaker_talk_raw" | awk -v RS='^$' -v FS='\\-\\-\\-' '{ n = split($0, a); print a[3] }')
    # speaker_abstract=$(trim "$speaker_abstract")

    # echo Name:$speaker_fullname
    # echo Twitter:$speaker_twitter
    # echo Home:$speaker_website
    # echo Bio:$speaker_bio
    # echo Title:$speaker_title
    # echo Abstract:$speaker_abstract

    PAGE_PATH=../_pages/${YEAR}/speakers/${ID}.markdown

    echo """---
layout: s-$YEAR-speaker
id: $ID
permalink: /$YEAR/speakers/$ID
title: \"$speaker_fullname at DevOpsDays Boston $YEAR\"
description: \"$speaker_title\"
---
    """ > $PAGE_PATH

    echo $INDEX
    echo $speaker_title

    yqstmt="""
      .items[$INDEX].id = \"$ID\" |
      .items[$INDEX].name = \"$speaker_fullname\" |
      .items[$INDEX].role = \"presenter\" |
      .items[$INDEX].bio = \"$speaker_bio\" |
      .items[$INDEX].date = \"$talk_date\" |
      .items[$INDEX].start_time = \"$talk_start_time\" |
      .items[$INDEX].end_time = \"$talk_end_time\" |
      .items[$INDEX].title = \"$speaker_title\" |
      .items[$INDEX].abstract = \"$speaker_abstract\" |
      .. style=\"double\"
    """
    if [ "$speaker_website" ]; then
      yqstmt="""$yqstmt |
      .items[$INDEX].website = \"$speaker_website\"
      """
    fi
    if [ "$speaker_twitter" ]; then
      yqstmt="""$yqstmt |
      .items[$INDEX].handles.twitter = \"$speaker_twitter\"
      """
    fi
    yq eval -i "$yqstmt" $DATA_PATH

    INDEX=$(($INDEX + 1))
done

# echo "$DATA_CONTENTS" > $DATA_PATH

# EXAMPLES


# INPUTS
# https://raw.githubusercontent.com/devopsdays/devopsdays-web/main/data/events/2021-boston.yml
# # program:
# #   - title: "laura-santamaria"
# #     type: talk
# #     date: 2021-09-27
# #     start_time: "09:20"
# #     end_time: "09:50"
#
# https://raw.githubusercontent.com/devopsdays/devopsdays-web/74b2a5eef8f1da268936958f9af5faf6756bfde6/content/events/2021-boston/speakers/ben-ellerby.md
# # +++
# # Title = "Ben Ellerby"
# # type = "speaker"
# # image = "ben-ellerby.jpg"
# # twitter = "EllerbyBen"
# # linkedin = "https://www.linkedin.com/in/benjaminellerby/"
# # +++
# #
# # AWS Serverless Hero & VP of Engineering at Theodo, working with startups to launch MVP’s and large corporates to deliver in startup speed. Editor of Serverless Transformation (blog, podcast and newsletter). Serverless London Meetup Organiser
#
# https://raw.githubusercontent.com/devopsdays/devopsdays-web/main/content/events/2021-boston/program/ben-ellerby.md
# # ---
# # title: "Load Testing AWS Serverless Architectures with Serverless"
# # Type: "talk"
# # Speakers: ["ben-ellerby"]
# # ---
# #
# # Serverless architectures on AWS, involving services like AWS Lambda, DynamoDB, Cognito, Step Functions, API Gateway, bring instant scalability when built and configured in the correct way. We’ll look at how AWS Serverless architectures need to be treated differently to ensure optimal scalability and how Serverless tools (like Serverless Artillery) can be used to verify scalability.
# #
# # Not only will we look at achieving scalability, we’ll also look at the tools and techniques to predict and limit the cost of scaling. To bring these topics to life we’ll look at the architecture of 2 live Serverless applications built on AWS for scale and discuss how they were architected, how costs were monitored and kept in line and how serverless load testing was used to verify scalability and catch edge cases.


# OUTPUTS
#
# /_pages/${YEAR}/speakers/${ID}.markdown
# # ---
# # layout: s-2021-speaker
# # id: angel-rivera
# # permalink: /2021/speakers/angel-rivera
# # ---

# /_data/s-${YEAR}-speakers.yaml
# # - id: ben-ellerby
# #   name: Ben Ellerby
# #   bio: |
# #     Prior to Shoreline, I spent 7.5 years at Amazon Web Services (AWS), where I ran their analytic and relational database services. Within analytics, this included Athena, Data Pipeline, EMR, Glue, LakeFormation, Managed Blockchain, and Redshift. Within relational databases, these were Aurora for MySQL and PostgreSQL and RDS for MariaDB, MySQL, Oracle, PostgreSQL, and SQL Server. Managing services deployed on millions of nodes while ticketing on a per-instance basis taught me the importance of distributed control and automation.
# #   role: presenter
# #   title: "Restarts and rollbacks don't fix everything: Automating Day 2 Operations"
# #   abstract: |
# #     As our systems grow exponentially larger and more complex, the challenge DevOps and SREs face to keep production systems online also grows. In order to get ahead of ticket queues and improve availability, there’s an imperative for us to automate remediation of issues entirely. This is more attainable than most people realize because while the causes of an incident may be in the thousands, the number of remediations is usually small and consistent.
# #
# #     In this session, I’ll describe real outages I saw at AWS, group them into their common infrastructure resolutions, and describe how we built speculative, automated resolutions that reduced tickets, improved availability, and reduced costs while growing our fleet 1000x. You’ll walk away with concrete ideas that you can put into place to improve availability and reduce burnout.
# #   handles:
# #     twitter: awgupta
# #     linkedin: awgupta
