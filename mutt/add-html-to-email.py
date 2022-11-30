#!/usr/bin/env python

import os
import sys

from email import policy
from email.mime.text import MIMEText
from email.parser import Parser

import markdown

# TODO: 
# This script fails completely when the input email is UTF-8 encoded. 
# Can we change that? 
# I've tried generating a policy object: take a look at that later. 


# Cheat Sheet (Inspired by Akkana): 
# When given a 'multipart/alternative' message, the last part of the message is
# preferred as the authoritative message body (RFC 2046). If we attach the HTML
# last (as shown below), the HTML will be shown on most clients. 
# 
# An example email hierarchy is shown below. 
# multipart/mixed
#   multipart/alternative
#     text/plain
#     multipart/related
#       text/html
#       inline image
#   other attachment
#   other attachment


def add_html(msg):
    body = msg.get_body()

    if body.get_content_type() == 'text/plain': 
        body.make_alternative()
        text = body.get_payload()[0]
        body.set_payload([MIMEText(text.get_content(), 'plain', 'utf-8'), to_html(text)])

    return msg


def to_html(text):
    text_data = text.get_content()
    html_data = markdown.markdown(text_data)
    return MIMEText(html_data, 'html', 'utf-8')

if __name__ == "__main__":
    # Use CRLF newlines as per RFC.
    msg = Parser(policy=policy.SMTP).parse(sys.stdin)
    msg = add_html(msg)
    os.write(1, msg.as_bytes())
