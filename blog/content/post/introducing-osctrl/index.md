---
title: 'Introducing osctrl'
description: '`osctrl`: A fast and efficient osquery management solution.'
summary: "**osctrl** is an open-source management solution for osquery that provides scalable TLS endpoint functionality with features for monitoring, configuration distribution, log collection, on-demand querying, and file carving." # For the post in lists.
date: '2019-08-26'
aliases:
  - introducing-osctrl
author: "Javier 🔐"

# featureImage: 'components.png' # Top image on post.
# featureImageAlt: 'Description of image' # Alternative text for featured image.
# featureImageCap: 'This is the featured image.' # Caption (optional).
# thumbnail: 'thumbnail.jpg' # Image in lists of posts.
# shareImage: 'share.jpg' # For SEO and social media snippets.

categories:
  - Projects
  - Security
tags:
  - osquery
  - osctrl
  - security
  - open source
# the following overrides the settings from params.toml:
showRelatedInArticle: true
showRelatedInSidebar: true
---

Introducing [osctrl](https://osctrl.net), a new solution to manage [osquery](https://osquery.io/) clients as TLS endpoint.

![osctrl admin page with the list of enrolled osquery nodes](osctrl-admin.png)

## What is osctrl?

[osctrl](https://osctrl.net) is a fast and efficient [osquery](https://osquery.io/) management solution, implementing its [remote API](https://osquery.readthedocs.io/en/stable/deployment/remote/) as TLS endpoint. It offers a scalable and reliable service that will help enhance your incident response and detection capabilities, by following a model where critical functions are split into different components.

![osctrl components](components.png)

## What can I do with osctrl?

* Monitor all your systems running [osquery](https://osquery.io/),

* Distribute [osquery](https://osquery.io/) configuration fast across all your enrolled nodes,

* Collect all the status and result logs, whether you want to store them or forward them to a different system ([Splunk](https://www.splunk.com), [ELK](https://www.elastic.co/what-is/elk-stack), [Kafka](https://kafka.apache.org/), [Graylog](https://www.graylog.org/)… ),

* Run quasi-real-time on-demand queries in your selected enrolled nodes,

* Carve files or directories from your enrolled nodes.

![CLI help](cli-help.png)

## Further Reading

* [osctrl code repository in Github](https://github.com/jmpsec/osctrl)

* [osctrl Documentation](https://www.osctrl.net/)

* [osquery main site](https://osquery.io/)

* [List of other open source solutions for osquery](https://www.uptycs.com/blog/deploying-osquery-at-scale-a-comprehensive-list-of-open-source-tools)

## Any questions?

If you have any questions about [osctrl](https://osctrl.net), feel free to create an [issue in Github](https://github.com/jmpsec/osctrl/issues) or reach out to me directly in Twitter ([@javutin](https://twitter.com/javutin)).

Also, there is the *#osctrl* channel in the [osquery official Slack](https://slack.osquery.io/).
