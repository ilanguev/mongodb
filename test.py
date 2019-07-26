#!/usr/bin/python

from pymongo import MongoClient
import uuid

client = MongoClient('mongodb://10.244.41.118:27017')
db = client.myDB

posts = db.posts
post_data = {
            'title': 'Python and MongoDB',
            'content': 'PyMongo is fun, you guys',
            'author': 'Scott'
}

for i in xrange(1,1000000):
    post_data['_id'] = uuid.uuid1()
    result = posts.insert_one(post_data)
    print('One post: {0}'.format(result.inserted_id))


