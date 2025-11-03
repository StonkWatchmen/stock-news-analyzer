import json

def lambda_handler(event, context):
    # Log the received event
    print("Received event:", json.dumps(event))

    # Extract message from the event
    message = event.get('message', 'Stocks new analyzer')

    # Create a response
    response = {
        'statusCode': 200,
        'body': json.dumps({
            'message': message
        })
    }

    return response