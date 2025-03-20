---
layout: post
title: "Raw AMQP on Azure Event Hubs"
date: 2025-03-20
categories: article
comments: true
---

<p class="summary">
Azure Event Hubs enables developer to use low-level protocols to send and receive events, when needed.
</p>


<div class="img-container">
  <img src="{{ site.url }}/imgs/RawAMQPOnAzureEventHubsCover.webp" alt="Raw AMQP on Azure Event Hubs Cover" />
</div>

Azure Event Hubs enables developer to use low-level protocols to send and receive events, when needed.

Low level protocols are used by the SDK, and SDKs usually provide a level of abstraction that is more suitable to the majority of use case.

In this post, we will dive into a super simple example of sending and receiving messages using raw AMQP.

<i class="fa fa-github" aria-hidden="true"></i> **Full working sample** [is available on Github as usual](https://github.com/MissaouiChedy/BlogSamples/tree/main/AzureEventHubsRawAMQP)

## Low-level Protocols Supported by Event Hubs

Azure Event Hubs supports [three protocols](https://learn.microsoft.com/en-us/shows/on-dotnet/azure-event-hubs-supported-protocols) for interacting with event streams, including:
- AMQP
- [Kafka's binary protocol](https://kafka.apache.org/protocol.html)
- [AMQP over Websocket](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-amqp-protocol-guide#amqp-outbound-port-requirements)
- [HTTP POST (send only)](https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/event-hubs/includes/event-hubs-connectivity.md#httpsrest-api)

While AMQP is the default, standard and preferred protocol to interact with Event Hubs, **the support of the Kafka protocol is valuable for interoperability** with [Kafka;](https://kafka.apache.org/) that can be required is some scenarios such as:
- Hybrid Cloud/Edge Messaging Setups
- Migration from Kafka to Event Hubs or vice versa

AMQP over websocket is interesting in allowing to **use AMQP over port 443,** in some organizations, with security and governance constraints, it might not be acceptable to allow AMQP traffic through corporate firewalls.

In other organizations, negotiating and setting up firewall rules can be time consuming due to heavy corporate processes, while https traffic is mostly likely already allowed.

## Just Enough AMQP Concepts

[AMQP](https://www.amqp.org/) is a lightweight, efficient messaging protocol designed for reliable asynchronous communication. It is used by many message brokers such as:
- [RabbitMQ](https://www.rabbitmq.com/)
- [Azure Service Bus](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-messaging-overview)
- [Apache Qpid](https://qpid.apache.org/)
- [Apache ActiveMQ](https://activemq.apache.org/)

AMQP 1.0 is the most recent version of the protocol and **focuses on the network and the message representation aspects.**

In this post, we will quickly go through some basic concepts used in our sample, **for more details please checkout:**
- [AMQP 1.0 in Azure Service Bus and Event Hubs protocol guide](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-amqp-protocol-guide)
- [This cool video series course about AMQP use in Azure messaging](https://www.youtube.com/playlist?list=PLmE4bZU0qx-wAP02i0I7PJWvDWoCytEjD)

### Connection

AMQP brokers expose an endpoint on which a client can initiate a handshake to establish a connection with the broker.

In AMQP, [connections](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-amqp-protocol-guide#connections-and-sessions) are typically **expensive to set up** because they involve a negotiation process between the broker and the client. This negotiation includes parameters such as:

- TLS settings (for secure communication)
- Message encoding format
- Maximum message size

Additionally, AMQP connections support keep-alive mechanisms, automatic reconnection, and multiplexing, allowing them to be long-lived and efficient.

Since establishing a connection is resource-intensive, client applications typically create a **single connection per process** and share it across multiple threads instead of opening multiple connections.

### Session

A single AMQP connection can manage multiple [sessions.](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-amqp-protocol-guide#connections-and-sessions)

The messaging flow of multiple sessions within one connection is handled using **multiplexing** and **priority management** capabilities.

Typically, a client application creates **one session per thread** to manage communication efficiently.

A session provides two mechanisms for bi-directional communication between the broker and the client:
- Channel-based flow
- Link-based flow

In this post, we will focus on the Link-based flow

### Link

AMQP [links](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-amqp-protocol-guide#links) are managed by a session and represent named, **unidirectional communication paths between the broker and the client.**

From the client's perspective, a link can be either:

- A sending link (producer) for sending messages to the broker.
- A receiving link (consumer) for receiving messages from the broker.

**Links are persistent** in the sense that they can survive temporary session or connection failures. 

If a session or connection is lost and then re-established, the client can recreate links using the same link name, allowing message transfer to resume without data loss or duplication (depending on the reliability mode used).

### Message

AMQP defines the concept of a [message](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-amqp-protocol-guide#messages) by specifying key aspects that ensure interoperability, efficiency, and reliability in message exchange between clients and brokers. These aspects include:

AMQP defines the concept of a message by focusing on the following aspects:
- Schema Definition and Solid Data Typing
- Wire representation with standardized binary encoding
- Message property declaration with standard and custom message properties

## Sending and Receiving with AMQPNetLite.Core

In our sample, we used the [AMQPNetLite.Core](https://github.com/Azure/amqpnetlite) library to interact with Event Hubs via AMQP.

Consider the main entry point implementation:
```csharp
...
string SasKeyName = "RootManageSharedAccessKey";
string SasKey = Uri.EscapeDataString("SAS_POLICY_KEY>");

string connectionString 
    = $"amqps://{SasKeyName}:{SasKey}@{EventHubNamespace}.servicebus.windows.net";
string sendEntityPath = EventHubName;
string receiveEntityPath 
    = $"{EventHubName}/ConsumerGroups/{ConsumerGroup}/Partitions/0";
int batchSize = 7;

/*
 * Open Connection, send batchSize of messages then close the connection 
 */
await SendMessageAsync(connectionString, sendEntityPath, batchSize);
...
/*
 * Open Connection, receive batchSize of messages then close the connection 
 */
await ReceiveMessageAsync(connectionString, receiveEntityPath, batchSize);
```

First, we start by defining a connection string by using a SAS access policy.

> Note here that SAS access policy secret is directly placed in the code, **please avoid this practice** for production scenario and use Managed Identities or Secret Stores instead

Then we define send and receive entity paths according to the format expected by Event Hubs:
- name of the event hub topic for sending
- a path in the following format for receiving from a partition:
  `{EventHubName}/ConsumerGroups/{ConsumerGroup}/Partitions/0`

Finally, we call the following methods:
- `SendMessageAsync` to send a batch of messages
- `ReceiveMessageAsync` to receive the previously sent batch of messages

The output of the program should be as following:
<div class="img-container">
![AMQP raw send output](/imgs/AmqpRawSendOutput.png)
</div>

Looking at the sending method:
```csharp
async Task SendMessageAsync(string connectionString,
  string entityPath, int batchSize)
{
  ...
  try
  {
    Address address = new(connectionString);
    connection = await Connection.Factory.CreateAsync(address);
    session = new Session(connection);

    var target = new Target { Address = entityPath };
    sender = new SenderLink(session, "sender-link", target.Address);

    for (int i = 0; i < batchSize; i++)
    {
      var message = $"Message {Guid.NewGuid()}";
      var messageBody = Encoding.UTF8.GetBytes(message);
      var amqpMessage = new Message
      {
          BodySection = new Data { Binary = messageBody }
      };
      await sender.SendAsync(amqpMessage);
      ...
    }
  }
  finally
  {
      sender?.Close(TimeSpan.Zero);
      session?.Close(TimeSpan.Zero);
      connection?.Close(TimeSpan.Zero);
  }
}
```

To create a *Sender Link,* we need to go through:
1. Establishing a connection
2. Creating a session
3. Creating a target which represents an Event Hub topic in our case

We then create a batch size count of messages and we use the `sender` to send the messages to the broker on by one.

Note here that at the end of the processing, we need to close the AMQP objects created by providing `TimeSpam.Zero` as timeout. This indicates to the closing operation to **not wait for an acknowledgement from the broker side.**

Considering the receiving method:
```csharp
async Task ReceiveMessageAsync(string connectionString,
  string entityPath, int batchSize)
{
  ...

  try
  {
    Address address = new(connectionString);
    connection = await Connection.Factory.CreateAsync(address);
    session = new Session(connection);

    var source = new Source { Address = entityPath };
    receiver = new ReceiverLink(session, "receiver-link", source.Address);
    for (int i = 0; i < batchSize; i++)
    {
        var message = await receiver.ReceiveAsync();
        if (message != null)
        {
            var body = message.BodySection as Data;
            var messageBody = Encoding.UTF8.GetString(body.Binary);
            Console.WriteLine($"Received message: {messageBody}");
            receiver.Accept(message);
        }
    }
  }
  finally
  {
    receiver?.Close(TimeSpan.Zero);
    session?.Close(TimeSpan.Zero);
    connection?.Close(TimeSpan.Zero);
  }
}
```

Similar to the sending method, in the receiving method we create a connection, session but this time a receiver link representing the Event hubs Consumer Group and partition to receive from.

> Note here that we created separate connections for sending and receiving, but this is only for demonstration purpose, as mentioned earlier better to create only one connection per process.

Calling the `receiver.ReceiveAsync` from within the same link will make sure to return events **from oldest to newest in the event stream.**

## Closing Thoughts
Using raw AMQP with Azure Event Hubs provides a deeper level of control, allowing for optimized message handling beyond what SDKs offer. 

However, as mentioned earlier, this is useful for some very specific uses cases; **better to use the SDK in most cases.**

Still, it remains interesting to explore how to communicate at the low-level. During this exploration, I discovered a interesting perspective about Azure Event Hubs shared in the [AMQP 1.0 guidelines,](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-amqp-protocol-guide) it is a **messaging system at the front** (while sending messages) but it is **more of a database in the back** (while receiving messages) 💡.
