---
number: xxx
status: ProtoXEP
shortname: NOT_YET_ASSIGNED
dependencies:
- XMPP Core
- XEP-001
authors:
- 
  firstname: Mateusz 
  surname: Piękos
  email: mateuszpiekos@gmail.com
  jid: pielas@jabber.org
- remko
revisions:
- 
  version: 0.0.1
  date: 2013-11-17
  initials: rt
  remark: First draft.
---

# Whiteboard Protocol

## Abstract

This specification defines an XMPP protocol extension that provides a generic
framework for shared editing. Applications include shared whiteboarding,
shared text editing, and other collaborative activities.


## Introduction

There have been several attempts in the past to create a protocol extension for shared 
editing (more specifically shared whiteboarding), which have been rejected in the
past for several reasons. Here, we present a protocol which uses a simple yet powerful
format, and is based on the sound and proven *Operational Transformation* technology,
widely used in collaborative applications. Its main
advantages are that changes done locally are immediate, without the need for explicit
synchronization for every operation, yet keeping all the documents consistent across
all participants in the session.

This extension focuses on one-to-one sessions, but it can also be extended to
multi-user scenarios.


## Requirements
  
The protocol defined herein was designed to address the following requirements:

- It shall allow 2 entities to collaboratively edit a shared document
- It shall be possible to do operations on the shared document without blocking it.
- It shall keep the shared document consistent for both entities
- It shall be extensible for different applications
  

## Operational Transformation

In this section, we illustrate the concepts and algorithms of *Operational Transformation*, 
the technology on which the shared whiteboarding protocol is based. We explain Operational
Transformation without going into any details on communication protocols.

### Example

#### Operations

Consider Romeo, who has a shared whiteboarding session with Juliet. Romeo starts by drawing
a circle on the initially blank canvas. In order to reason about the operations he performs
on the whiteboard, Romeo keeps a history of all the operations that both he and Juliet
performed on the whiteboard, called a *state space*. After drawing the circle, the state
space looks like this:

            s_0 (Juliet)
     .   .   o   .   .
            /
        a  / 
          /
     .   o   .   .   .
        s_1 (Romeo)

Each dot represents a *state* of the session. For example, *s<sub>0</sub>* is
the initial state, the blank canvas, whereas *s<sub>1</sub>* is the state with
the circle in the drawing. Each line between states represent an operation on
the shared whiteboard. We represent Romeo's operations as lines moving down to
the left, and Juliet's operations as lines moving down to the right. So far,
there is only one operation, *a*, which represents Romeo drawing the circle on
the blank canvas. At this point, from Romeo's point of view, Romeo is in state
*s<sub>1</sub>*, whereas Juliet is still in state *s<sub>0</sub>*. 

Since the goal of shared whiteboarding
is to make sure that both parties are working on the same drawing, Romeo sends
all the necessary information of the circle he just drew to Juliet, so she can
also draw it on her side. Once she acknolwedges she received and processed this
information, Romeo knows Juliet is in state *s<sub>1</sub>* as well.

            s_0
     .   .   o   .   .
            /
        a  / 
          /
     .   o   .   .   .
        s_1 (Romeo, Juliet)


#### Transformed operations

Now, let's suppose both Romeo and Juliet each draw a different square on top
of the circle simultaneously. Before they send each other the information about their
operations, the state space from Romeo's point of view looks like this:

                  s_0
     .   .   .   o   .   .
                /
             a / 
              / s_1 (Juliet)
     .   .   o   .   .   .
            /             
         b / 
          /
     .   o   .   .   .   .
      s_2 
    (Romeo) 

Romeo still thinks Juliet is in *s<sub>1</sub>*, so he sends information about his
operation *b* to Juliet. However, shotly thereafter, he receives a message from
Juliet of her square-drawing operation *c* she did while in state *s<sub>1</sub>*, 
so the state space now looks like this:

                  s_0
     .   .   .   o   .   .
                /
             a / 
              / s_1
     .   .   o   .   .   .
            / \  
         b /   \ c
          /     \
     .   o   .   o   .   .
      s_2         s_3
    (Romeo)     (Juliet)
    
Romeo realizes that Juliet has a drawing with her square on top of the circle, while
he has a drawing with his square on top of it. If Romeo applies Juliet's operation *c*
directly on his current drawing, and Juliet would simply draw operation *b* on hers 
(once she receives the information), the drawings would be inconsistent: indeed, the order of
the squares would be different. Therefore, instead applying operation *c* directly,
Romeo needs to apply a modified version *c'*, while Juliet needs to apply a modified
version *b′*, in order to converge to a common state *s<sub>4</sub>* again:

           s_1
        .   o   .
           / \  
        b /   \ c
         /     \
    s_2 o   .   o s_3
         \     /    
        c'\   / b′ 
           \ /
        .   o   . 
           s_4
 
So, what are these operations *c'* and *b′* in this case? Let's assume that Romeo
and Juliet agreed up front that, in a case of conflicting additions, Juliet's
addition goes first. This means that operation *c'* (applied on Romeo's
side) is actually "Insert the object from operation *c* under the object
inserted in operation *b*", whereas *b′* (applied on Juliet's side) is simply 
"Append the object of
operation *b* on top of the object of operation *c*".
Note that both parties can independently compute which
operation to apply in order to converge, so no communication is necessary to decide
how to resolve the conflict. We assume both sides know, for each possible combination of different 
operations starting from the same state, how these operations need to be transformed
in order to get a pair of operations that gets both sides back to the same state again.
We will refer to this transformation as the *xform* function, which is applied on 2 states,
and results in 2 transformed states.

So, if we go back to the example, Romeo decides to apply operation *c'*.


                  s_0
     .   .   .   o   .   .
                /
             a / 
              / s_1
     .   .   o   .   .   .
            / \  
         b /   \ c
          /     \
     .   o   .   o   .   .
      s_2 \       s_3
         c'\    (Juliet)
            \
     .   .   o   .   .   .
            s_4
           (Romeo)

In the meantime, Juliet also realized there was a conflict, applied the
transformed operation *b′* on her side, and sends this information to Romeo,
who in turn can conclude that the drawings have new converged:

                  s_0
     .   .   .   o   .   .
                /
             a / 
              / s_1
     .   .   o   .   .   .
            / \  
         b /   \ c
          /     \
     .   o   .   o   .   .
      s_2 \     / s_3
         c′\   / b′ 
            \ /
     .   .   o   .   .   .
            s_4
       (Romeo, Juliet)

Given the state transformation function above, it's clear that
Romeo and Juliet can easily resolve any situation where the states diverged by one
operation on each side. However, in practice, situations can diverge more than this, so
more computation needs to be done.

#### Combining transformed operations

Before moving on to the complex case, let's make the roles of Romeo and Juliet more
specific. In a shared session, we are going to designate one party to be the *client*, and 
the other the *server*. In a one-to-one session such as the one from our example, either party 
can play the client or server role, it just needs to be agreed up front (e.g. the initiator 
of the session). We make this distinction so we can have different focus for the algorithms
on the client and the server side, allowing the server algorithm to scale
to multi-user scenarios (not handled in this specification). Concretely, in our example,
let's assume Romeo is the client, and Juliet is the server.

Let's assume that Romeo starts from a blank canvas again, and applies 2 operations *a*
and *b*:

                s_0 (Juliet)
     .   .   .   o   .   .
                /
             a / 
          s_1 /      
     .   .   o   .   .   .
            /    
         b /      
          /       
     .   o   .   .   .   .
        s_2 (Romeo)

Instead of sending off both operations to Juliet for processing, we impose
the restriction that a client can only send operations to the server if they
are rooted from a state in the server's history. Since Juliet only has *s<sub>0</sub>*
in her history, Romeo only sends operation *a*, and waits for confirmation.
In the meantime, Juliet already applied operation *c* on her side, and Romeo
is notified of this:

                s_0 
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3 (Juliet)
     .   .   o   .   o   .
            /    
         b /      
          /       
     .   o   .   .   .   .
        s_2 (Romeo)

Since this operation *c* is rooted on top of a different state *s<sub>0</sub>* than 
Romeo's current state, it needs to be transformed so it can be applied on top of *s<sub>2</sub>*.
Since we can only apply the *xform* function on 2 operations rooted from the same state,
we can compute the states *a′* and *c′*:

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3
     .   .   o   .   o   .
            / \     /
         b /   \c′ /a′ 
          /     \ /
     .   o   .   o   .   .
        s_2

Using this result, we can apply the same *xform* function on *b* and *c′*, in order to get
to our desired operation *c′′* rooted on top of the current state. We can discard the intermediate
results, which brings Romeo in the following state:

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3 (Juliet)
     .   .   o   .   o   .
            /        
         b /            
          /        
     .   o   .   .   .   .
     s_2  \
        c′′\
            \
     .   .   o   .   .   .
            s_4

Before any confirmation on the still pending operation *a* comes in from Juliet, Romeo decides
to apply another operation *d* on his whiteboard:

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3 (Juliet)
     .   .   o   .   o   .
            /        
         b /            
          /        
     .   o   .   .   .   .
     s_2  \
        c′′\
            \
     .   .   o   .   .   .
            / s_4
         d /
          /
     .   o   .   .   .   .
        s_5 (Romeo)

At this point, Romeo receives notification about another operation *e* applied by Juliet:

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3         
     .   .   o   .   o   .
            /         \
         b /           \ e
          /             \
     .   o   .   .   .   o s_6 (Juliet)
     s_2  \
        c′ \
            \
     .   .   o   .   .   .
            / s_4
         d /
          /
     .   o   .   .   .   .
        s_5 (Romeo)

Again, Romeo can transform *e* such that it can be applied on top of his current
state *s<sub>5</sub>*, by repeatedly applying *xform* on the current and intermediate
operations, resulting in the following state:

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3         
     .   .   o   .   o   .
            /         \
         b /           \ e
          /             \
     .   o   .   .   .   o s_6 (Juliet)
     s_2  \
        c′ \
            \
     .   .   o   .   .   .
            / s_4
         d /
          /
     .   o   .   .   .   .
      s_5 \
        e′ \
            \
     .   .   o   .   .   .
            s_7 (Romeo)

At this point, Juliet has received Romeo's initial operation *a*, applied a transformed
version *a′*, and sends this information to Romeo:

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3         
     .   .   o   .   o   .
            /         \
         b /           \ e
          /             \
     .   o   .   .   .   o s_6
     s_2  \             /
        c′ \           / a′
            \         /
     .   .   o   .   o   .
            / s_4     s_8 (Juliet)
         d /
          /
     .   o   .   .   .   .
      s_5 \
        e′ \
            \
     .   .   o   .   .   .
            s_7 (Romeo)

At this point, Romeo can now apply *xform* a few times again to transform operation *b*,
such that it is rooted on top of *s<sub>8</sub>*, and send off the result to Juliet for 
processing.

By combining invocations of the *xform* functions, Romeo can now keep on processing
Juliet's operations and sending off his own, and make his state converge with Juliet's 
eventually.


#### The Bridge

In the previous example, we have repeatedly called *xform* on actual and intermediate
operations in the state space. Although this is correct, doing this in practice results
in repeated recomputation of the same intermediate states. A way to avoid this is to
constantly maintain a *bridge* of operations that goes from the current state of the
server to the current state of the client. 

Let's revisit the previous example, where Romeo starts off with 2 local operations.

                s_0 (Juliet)
     .   .   .   o   .   .
                //
             a // 
          s_1 //      
     .   .   o   .   .   .
            //    
         b //      
          //       
     .   o   .   .   .   .
        s_2 (Romeo)

At this point, the bridge runs from *s<sub>0</sub>* to *s<sub>2</sub>*, and is simply 
a combination of all the operations that haven't been processed by Juliet yet. Upon
receiving operation *c* from Juliet, each operation of the bridge is transformed by
exactly the same repeated invocations of *xform* as before, resulting in a new bridge 
from *s<sub>3</sub>* to *s<sub>4</sub>*, consisting of *a′* and *b′*:

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3 (Juliet)
     .   .   o   .   o   .
            /       //
         b /       // a′
          /       //
     .   o   .   o   .   .
     s_2  \     //
        c′ \   // b′ 
            \ //
     .   .   o   .   .   .
            s_4 (Romeo)

When Romeo applies operation *d* locally, the bridge is extended by this operation:

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3 (Juliet)
     .   .   o   .   o   .
            /       //
         b /       // a′
          /       // 
     .   o   .   o   .   .
     s_2  \     //
        c′′\   // b′
            \ //
     .   .   o   .   .   .
            // s_4
         d // c′
          //
     .   o   .   .   .   .
        s_5 (Romeo)

Upon receiving operation *e* from Juliet, we can again simply repeatedly apply *xform* on the 
base of the bridge, taking us one step down on each invocation, building a new bridge ending
in the final state:

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3         
     .   .   o   .   o   .
            /         \
         b /           \ e
          /             \
     .   o   .   .   .   o s_6 (Juliet)
     s_2  \             //
        c′ \           // a′′ 
            \         //
     .   .   o   .   o   .
            / s_4   //
         d /       // b′′
          /       //
     .   o   .   o   .   .
      s_5 \     //
        e′ \   // d′′
            \ //
     .   .   o   .   .   .
            s_7 (Romeo)


Finally, when Romeo receives confirmation that *a′* has been applied, he can remove *a′* from
the bridge, and submit the already computed b′ off to Juliet.

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3         
     .   .   o   .   o   .
            /         \
         b /           \ e
          /             \
     .   o   .   .   .   o s_6 (Juliet)
     s_2  \             /
        c′ \           / a′′ 
            \         /
     .   .   o   .   o   .
            / s_4   //
         d /       // b′′
          /       //
     .   o   .   o   .   .
      s_5 \     //
        e′ \   // d′′
            \ //
     .   .   o   .   .   .
            s_7 (Romeo)


#### The Server

So far, we have only focused on Romeo, the client side of the session. Because the client
has the restriction to only send operations rooted in the server's history, it needs to maintain
the entire state space and constantly transform its unprocessed operations before sending the
next one off for processing. 

The server side is, however, much simpler. Since all incoming operations are guaranteed to
be rooted on top of the history, all the server needs to do is maintain is its own history, and
transform any incoming operations against this linear history. This means the server side
can scale with multiple participants in a shared session.


#### Conclusion

In this example, we illustrated how Operational Transformation works. In essence,
it consists of the following parts:

- A set of operations in a target domain (e.g. whiteboarding)
- A transformation function *xform*, which, for any combination of operations rooted from
  the same state, computes which operations need to be applied in order to converge to an
  equivalent state again
- A client and a server algorithm that maintains the state space, and decides which operations
  to transform and to send out for processing. The client algorithm needs to do the heavy lifting
  and an extensive state space, whereas the server algorithm is simple and only needs to maintain a
  very limited history for its transformations.

The rest of this document formalizes these concepts, and also specifies the communication
protocol for a shared session.


### Entities

TODO: Client vs Server

### Transformation Function

Given a transformation function 

> xform(a,b) = (a′, b′) 

such that 

> b′ ○ a ≡ a′ ○ b

This function, given 2 operations *a* and *b*, computes the operations *b′* and *a′*, such that,
when applied after applying *a* and *b* respectively, result in the same state. Or, when
representing this schematically in the state space:

        .   o   .
           / \  
        a /   \ b
         /     \
        o   .   o    
         \     /    
        b′\   / a′ 
           \ /
        .   o   . 

### Client algorithm

In this section, we explain the details of the conflict resolution algorithm underlying
Operational Transformation.

Based on the *xform* function, we define an algorithm that decides which operations to apply
in order to make 2 parties converge to the same state when they have diverged.


### Server algorithm

### Whiteboarding

In this section, we describe the concrete operations and transformation functions,
used for applying Operational Transformation on shared whiteboarding sessions.

#### Whiteboarding Operations

In this section, we define the operations that can be used in a whiteboarding session.

#### Whiteboarding Operation Transformation Function

In this section, we define the transformation function *xform* on all combinations of
the whiteboard operations.


## Use Cases

### Session Initialization
    
*Example: Entity requests a new shared text editing session*

    <iq from="romeo@montague.net/garden"
        to="juliet@capulet.com/balcony"
        type="set">
      <session-request xmlns="http://swift.im/shedit" sid="session1">
        <text xmlns="http://swift.im/shared-text"/>
      </session-request>
    </iq>


*Example: Session accepts request*

    <iq to="juliet@capulet.com/balcony"
        from="romeo@montague.net/garden"
        type="set">
      <session-accept xmlns="http://swift.im/shedit" sid="session1"/>
    </iq>

*Example: Session rejects request*

    <iq to="juliet@capulet.com/balcony"
        from="romeo@montague.net/garden"
        type="set">
      <session-terminate xmlns="http://swift.im/shedit" sid="session1"/>
    </iq>
    
TODO: Add extra metadata in requests/rejects: reason, continuation, ...

### Session Termination

*Example: Session is terminated by an entity*

    <iq to="juliet@capulet.com/balcony"
        from="romeo@montague.net/garden"
        type="set">
      <session-terminate xmlns="http://swift.im/shedit"/>
    </iq>
  
<!--
### 1st situation
    
In case when client and server exchanges operations in large intervals and they
know about each applied operation, operations doesn't have to be transformed
and are just applied and added to the history. Here is example of such
situation:

  *Example: Client sends a line*

    <iq from="romeo@montague.net/garden"
        to="juliet@capulet.com/balcony"
        type="set">
      <wb xmlns="http://swift.im/whiteboard" type="data">
        <operation type="insert" pos="1" id="a" parentid="0">
          <line id="ab" x1="10" y1="10" x2="20" y2="30" 
              stroke="#000000" stroke-width="1" opacity="1" />
        </operation>
      </wb>
    </iq>

Server should apply it and send it back to inform client about it.

  *Example: Server confirms the operation*

    <iq from="juliet@montague.net/balcony"
        to="romeo@capulet.com/garden"
        type="set">
      <wb xmlns="http://swift.im/whiteboard" type="data">
        <operation type="insert" pos="1" id="a" parentid="0">
          <line id="ab" x1="10" y1="10" x2="20" y2="30" 
              stroke="#000000" stroke-width="1" opacity="1" />
        </operation>
      </wb>
    </iq>

  *Example: Server sends a rectangle*

    <iq from="romeo@montague.net/garden"
        to="juliet@capulet.com/balcony"
        type="set">
      <wb xmlns="http://swift.im/whiteboard" type="data">
        <operation type="insert" pos="2" id="b" parentid="a">
          <rect id="ab" x="10" y="10" width="20" height="30"
              stroke="#000000" fill="#334422" stroke-width="1" opacity="1" fill-opacity="0.75" />
        </operation>
      </wb>
    </iq>

Because it's parented off "a" client should apply it(client doesn't send back acks).
Data exchange looks like that: (C is client, S is server)

- C -> S: insert(1, a, 0, line) (insert line at first position with ID="a" and parented off operation "0". It doesn't matter how elements, in this example line, looks like.)<br />
- S -> C: insert(1, a, 0, line) <br />
- S -> C: insert(2, b, a, rect) <br />

After this exchange client and server contains [line, rect] elements(in this order).
    
  
### 2nd situation
    
Let's try more complicated situation. Here the client performed own operation when in the meantime server performed own. Let's assume that client side is line (there was operation insert(1, a, 0 line)) and server side is rect (insert(1, b, 0, rect)).

When operation "a" is performed on the client side, it is sent out to the server C -> S: insert(1, a, 0, line), but server doesn't receive that immediately and performs own operation "b" without knowing of "a" and send it out S -> C: insert(1, b, 0, rect). After a while client receives operation from the server and founds that it isn't parented off "a"(which was last operation in history), so it has to be transformed against all operations applied after "0"(in this case it's only "a"). Transform(a, b) (It's transform(Client operation, server operation)) returns 2 operations b′(insert(2, b, a, rect)) and a′(insert(1, a, b, line)) as on picture below:

  <img src='diamond.png' /><br />

Client want to apply "b" so it uses "b′" instead(because it's parented off last operation in history). After applying it it contains [line, rect].

When server receives "a" operation from client it proceeds almost identical, but instead of using "b′" result from transformation it uses "a′" and send it immediately to the clients(server sends out every applied operation) S -> C: insert(1, a, b, line). After applying "a′" server side is [line, rect] which is the same as client side.

    
  
### 3rd situation
    
Situation here is very similar to previous one, the difference is that client
performed 2 operations instead of 1. So let's assume that client performes
operation insert(1, a, 0, line)(client side is [line]) and sends it to the
server. Before receiving anything from the server it performed one more
operation insert(2, b, a, rect)(so it's [line, rect]), but it doesn't send that
because client didn't receive ack for "a" operation. So the client performed 2
operations, but server still doesn't know about them and it performs own
operation insert(1, c, 0, ellipse)(so server side is [ellipse]) and of course
sends it to the client. Let's move to the client side. It now receives "c"
operation from the server, but it can't be applied because there were two
operations performed after "0"(which is parent of "c"). So transformation
function has to be used two times. First transformation is transform(a, c) we
are interested in "c'" result which is insert(2, c, a, ellipse), because its
parent isn't "b" which is last operation in history we need to transform it one
more time. Next transformation is transform(b, c'), left operation "c''" which
is insert(3, c, b, ellipse) can be applied on client side. After that client
side is [line, rect, ellipse]. Right operation "b′" which is insert(2, b, a,
rect)(the parent is "a′" not "a", but it doesn't matter because server don't
have normal "a") needs to be stored somewhere because this could be next
operation to send to server(but client still doesn't have any ack from server
about applying "a", so it couldn't be sent). Server now receives "a" operation
which has to be transformed. This transformation is identical to first
transformation on the client side, but server applies and send back "a′" result
from it which is insert(1, a, c, line). After that server is [line, ellipse].
When client receives this transformed operation as ack it could finally send
"b", but it has to be parented somewhere in server history, so operation to
send is "b′" from last client side transformation. Server can apply and send
back this operation without transformation because its parent is last operation
in history. After this operation server side is [line, rect, ellipse] which is
the same as client side.
    
  
### 4th situation
    
Let's get into even more complicated situation.

<img src='situation.png' /> <br />

The client applied operations "a" and "b" when server applied operation "c". In this situation operation "a" should be sent immediately and correctly transformed operation "b" should be sent after receiving operation "a" from the server. In my implementation I implemented this algorithm(in client) as following:

- if client doesn't wait for any ack from the server it should send own operation to it and add this operation to "bridge"(in this example it's "a")
- if client waits for ack it only adds local operation to "bridge"(in this example it's "b")
- on received operation from server which isn't ack("c" in this example) client should do the transformation of first element of "bridge" and received element(a and c). Left result should be stored as a temporary value(t1) and right result should replace old operation in bridge(in this situation "a" operation from bridge should be replaced by right result of transformation, which is "a′" here). You should do this with every occurence in bridge, but in next steps, temp operation should be used as server operation. After iterating over whole bridge last temp value should be applied on the client side.(in this situation next transformation is "b" and "t1" and result is "c'" and "t2", "c'" should be applied) 
- on received operation from server which is ack("a′" in this example) client should remove this element from bridge and send next element from bridge("t2" in this example, it is known that "a′" is the last server operation so "t2" is parented off somewhere in server history)
- when both sides have the same amount of operations it means that they are both synchronized

In this example somebody applied operation "d" after applying "a′" on server
side. In the next steps client will receive "d" from the server, recompute
"bridge"(which has only one element now) apply "d'" operation locally and then
receive "b′" ack which is transformed version of "t2".
    
    
Server side is much simpler than client side, because the assumption that it
must receive only operations parented off somewhere in it's operations history.
So when it receives any operation it checks if it is parented off last
operation if it is it should be applied and sent back and if it isn't it should
be transformed step by step to receive final operation which should be applied
and sent back. In this example server firsts sent out own operation "c" and
then receives operation "a" which has the same parent as "c" so it should be
transformed against "c" and result should be applied and sent back(to every
client). Next operation in example is "d" which is own operation so it should
be added to history and sent back, after that server receives "t2" which is
transformed "b", but it needs to be transformed one more time to receive
operation which could be appended to the history(of course "b′" should be sent
back to clients). 
    
  
### Transformations
    
Here is described transformation function for every combination of input operations
    
#### insert, insert

This is quite simple transformation. For transformation(insert(pos1, a, 0, element1), insert(pos2, b, 0, element2)) output is: 
insert(pos2+1, b, a, element2) and insert(pos1, a, b, element1) if pos1 <= pos2
insert(pos2, b, a, element2) and insert(pos1+1, a, b, element1) if pos1 > pos2
      

#### update, update

Two updates are more complex than two inserts, to simplify operations I don't merge two updates to the same element and apply only server side update in such situations(ignoring local one).  
To describe update operation I will use such form "update(position, new position, id, parent id, element)"
      
For transformation(update(pos1, newpos1, a, 0, element1), update(pos2, newpos2, b, 0, element2)) output is: 

    if "pos1 < pos2" and "newpos1 > newpos2" then first result is update(pos2-1, newpos2, b, a, element1); 
    if "pos1 < pos2" and "newpos1 >= newpos2" then first result is update(pos2-1, newpos2-1, b, a, element1); 
    if "pos1 >= pos2" and "newpos1 >= newpos2" then first result is update(pos2, newpos2-1, b, a, element1); 
    if none of above first result is just update(pos2, newpos2, b, a, element1);


    if "pos2 < pos1" and "newpos2 > newpos1" then second result is update(pos1-1, newpos1, b, a, element1); 
    if "pos2 < pos1" and "newpos2 >= newpos1" then second result is update(pos1-1, newpos1-1, b, a, element1); 
    if "pos2 >= pos1" and "newpos2 >= newpos1" then second result is update(pos1, newpos1-1, b, a, element1); 
    if none of above second result is just update(pos1, newpos1, a, b, element2); 
    

## Glossary
  
- **Operation ID**: ID assigned to operation, unique within the session.
- **Parent ID**: ID of the preceding operation in operation history.
- **Operation history**: List of operations which was applied on specified
  side(client or server side).
- **Server**: Role assinged to one of the clients (In one-to-one session it's
  assigned to client which requests the session). It should receive only one
  operation at time(clients should wait for ack to send next operations) and
  these operations should be parented off somewhere in server history. Because
  of that assumptions server is quite simple and it has to store only own
  operation history.
- **Client**: Role assigned to rest of the clients. They have to compute own
  and server operations, so they are more complicated than server.
- **Transformation**: Function which computes two operations to merge one step diverge.<br/>
  Diamond.png
  Here is example when client applied operation *a* and server applied
  operation *b*(both has the same parent). Transformation function computes
  operation *a′* parented off *b* and operation *b′* parented off *a*. Computed
  operations have such property that, after applying these operations client
  and server views are the same.
- **Bridge**: Client side buffer for own operations which haven't been sent to the server.
    

-->

## Implementation Notes
 
OPTIONAL

## Accessibility Considerations

OPTIONAL.

## Internationalization Considerations

OPTIONAL.

## Security Considerations

REQUIRED.

## IANA Considerations

REQUIRED.

## XMPP Registrar Considerations

REQUIRED.

## XML Schema

REQUIRED for protocol specifications.

## Acknolwedgements

The introductory example from this specification is based on 
[Understanding and Applying Operational Transformation][ot-intro].


[ot-intro]: http://www.codecommit.com/blog/java/understanding-and-applying-operational-transformation]

