#!/usr/bin/env python
# -*- coding: utf-8 -*-
import paho.mqtt.client as mqtt 
import time
import bson
import json
import random

topic = "python/mqtt"
client_id = f'python-mqtt-{random.randint(0, 1000)}'
current_area = 0
current_path_index = 0
current_area_id = "mow-01"

# The callback for when the client receives a CONNACK response from the server.
def on_connect(client, userdata, flags, reason_code, properties):
    print(f"Connected with result code {reason_code}")

def on_connect_fail(client, userdata, flags, rc):
    print('error')

def on_subscribe(client, userdata, mid, reason_code_list, properties):
    # Since we subscribed only for a single channel, reason_code_list contains
    # a single entry
    if reason_code_list[0].is_failure:
        print(f"Broker rejected you subscription: {reason_code_list[0]}")
    else:
        print(f"Broker granted the following QoS: {reason_code_list[0].value}")

def on_unsubscribe(client, userdata, mid, reason_code_list, properties):
    # Be careful, the reason_code_list is only present in MQTTv5.
    # In MQTTv3 it will always be empty
    if len(reason_code_list) == 0 or not reason_code_list[0].is_failure:
        print("unsubscribe succeeded (if SUBACK is received in MQTTv3 it success)")
    else:
        print(f"Broker replied with failure: {reason_code_list[0]}")
    client.disconnect()



# The callback for when a PUBLISH message is received from the server.
def on_message(client, userdata, msg):
    print(msg.topic+" "+str(msg.payload))

def robot_state_publish():

    global current_area, current_path_index 
    current_area = current_area + 1
    current_path_index = current_path_index + 1
    j ={ "d":
        {
        "battery_percentage": 0.8,
        "gps_percentage": 0.9,
        "current_action_progress": 0.56,
        "current_state": "AREA_RECORDING",
        "current_sub_state": "",
        "current_area": current_area,
        "current_area_id": current_area_id,
        "checkpoint_area_id": current_area_id,
        "current_path": current_path_index,
        "current_path_index": current_path_index,
        "emergency": 0,
        "is_charging": 0,
        "rain_detected": 0,
        "pose": {
            "x": 0,
            "y": 0,
            "heading": 0,
            "pos_accuracy": 0,
            "heading_accuracy": 0,
            "heading_valid": 0
            }   
        }
    }

    topic_data = bson.dumps(j)
    client.publish("robot_state/bson", topic_data)

def action_publish():

    j ={ "d":
        [
           {
            "action_id": "mower_logic:area_recording/start_manual_mowing",
            "action_name": 0,
            "enabled": 0
            },
            {
            "action_id": "mower_logic:area_recording/stop_manual_mowing",
            "action_name": 0,
            "enabled": 1
            },
                       {
            "action_id": "mower_logic:mowing/skip_area",
            "action_name": 0,
            "enabled": 1
            },
            {
            "action_id": "mower_logic:mowing/skip_path",
            "action_name": 0,
            "enabled": 1
            },         
        ]
    }

    topic_data = bson.dumps(j)
    client.publish("actions/bson", topic_data)

    



def mowing_progress_publish():

    geometry = {
        "d": {
            "current_area_id": current_area_id,
            "areas": {
                current_area_id: {
                    "area_id": current_area_id,
                    "paths": [
                        {
                            "path_id": "pa_000001",
                            "order": 1,
                            "slicer_source": { "path_id": 1 },
                            "path_direction": "forward",
                            "points": [ { "x": 0, "y": 0 }, { "x": 2, "y": 0 } ]
                        },
                        {
                            "path_id": "pa_000002",
                            "order": 2,
                            "slicer_source": { "path_id": 2 },
                            "path_direction": "reverse",
                            "points": [ { "x": 0, "y": 1 }, { "x": 2, "y": 1 } ]
                        }
                    ]
                }
            }
        }
    }

    status = {
        "d": {
            "current_area_id": current_area_id,
            "areas": {
                current_area_id: {
                    "area_id": current_area_id,
                    "state": "mowing",
                    "percent": min(current_path_index * 10, 100),
                    "current_path_id": "pa_000001",
                    "paths": [
                        {
                            "path_id": "pa_000001",
                            "mow_status": "mowing",
                            "current_pose_index": current_path_index,
                            "completed_percent": min(current_path_index * 10, 100)
                        },
                        {
                            "path_id": "pa_000002",
                            "mow_status": "unmowed",
                            "current_pose_index": 0,
                            "completed_percent": 0
                        }
                    ]
                }
            }
        }
    }

    client.publish("map/mowing_progress/json", json.dumps(geometry), retain=True)
    client.publish("map/mowing_progress/status/json", json.dumps(status), retain=True)

def publish(client):
    while True:
        time.sleep(1)
        robot_state_publish()
        action_publish()
        mowing_progress_publish()

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.on_connect = on_connect
client.on_connect_fail = on_connect_fail
client.on_message = on_message
client.on_subscribe = on_subscribe
client.on_unsubscribe = on_unsubscribe
client.connect('127.0.0.1', 1883, 60)
client.loop_start()
publish(client)
client.loop_stop()    