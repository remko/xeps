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


## NOTES

- The XEP first gives an elaborate explanation of how the reasoning behind OT, how the 
  control algorithm works, then presents a/the control algorithm, and then talks about the protocol.
  In principle, the XEP could also start with the pure protocol, whiteboard operations,
  and transformation specification for the operations, and just specify that incoming
  operations need to be transformed by combining the xform function correctly, and leave
  a concrete control algorithm out of the discussion.
  An explanation of a/the control algorithm for doing the transformations could come afterwards too.

- The XEP only talks about whiteboarding. The Operational Transformation approach can be used
  for any 'shared editing' application, though (for example, shared text editing). I have
  tried to keep the generic OT and the whiteboard-specific part separated in the discussion 
  and the protocol, so this could be split up into several XEPs (e.g. a general 'Shared Editing'
  XEP, a 'Shared Whiteboard Editing' XEP, and a 'Shared Text Editing' XEP). 
  If we decide there is no interest in keeping this open, some protocol elements can probably
  be simplified and collapsed together into the 'urn:xmpp:wb' namespace.

- We only describe a one-to-one shared whiteboarding session. In order to support multi-user
  editing, nothing would have to change in the current algorithms and protocols. However,
  multi-users raises several questions, and would require some extras in the protocol:
  how do users join a common whiteboard; do we use a decentralized or centralized (e.g. 
  with a dedicated component) approach, or both; if decentralized, what happens when
  the entity playing the server role goes away (how is the shared whiteboard handed over,
  who takes over the new role); ...
  
- The whiteboarding operations we use are simple: you can only add, remove, or update 1 
  element at a time in a single operation. The advantage is that the transformation function
  is easy, and that conflicts are easy to resolve. The disadvantages are:

    - An operation has less expressive power (you can't describe every possible whiteboard 
      manipulation in a single operation)
    - You cannot compose operations into a single operation. Since the client can only
      have one operation in flight, it potentially needs to buffer lots of operations.
      If these can be composed, the complete buffer can be sent for processing in one go,
      whereas now they need to be sent operation by operation, which means a round-trip
      and processing time for each operation, which in turn means a higher chance that
      the states of the local versions of the whiteboard will diverge, and that operations
      need to be resolved.
  
    Other OT systems (such as Google Wave) define their operations in a more powerful way, 
    such that they are composable. Doing this makes the transformation function a lot 
    more complex though, and could cause conflict resolution to lose more information.

- There currently isn't any support for resuming whiteboard sessions after an entity drops
  off. This should just involve the server sending the whiteboard on the initial session-accept.

- There currently isn't any support for consistency checking (to see whether the whiteboard is still
  consistent with the server), using some sort of fingerprints.

- The server's `operation` attribute has different required attributes than the client's (the client
  does not have a `target-state` attribute, and the server does not need a `source-state`
  attribute). Should this be enforced in the schema? How? Using different namespaces?

<!-- 
  For Pielas
  - I'm not using the 'id' in the delete operations. I noticed the algorithm using the 'pos',
    but the UI uses the 'id'. Is it ok to remove the 'id', and assume everything is done positionally?
-->

## Introduction

There have been several attempts in the past to create a protocol extension for shared 
editing (more specifically shared whiteboarding), which have been rejected in the
past for several reasons. Here, we present a protocol which uses a simple yet powerful
format, and is based on the sound and proven *Operational Transformation* (OT) technology,
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

In this section, we illustrate the concepts and control algorithms of *Operational Transformation*, 
(OT) the technology on which the shared whiteboarding protocol is based. We explain Operational
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
also draw it on her side. Once she acknowledges she received and processed this
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
operation *b* to Juliet. However, shortly thereafter, he receives a message from
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
the figures would be different. Therefore, instead applying operation *c* directly,
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
We will refer to this transformation as the *xform* function, which is applied on 2 operations
starting from the same state, and results in 2 transformed operations.

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

Given the *xform* state transformation function above, it's clear that
Romeo and Juliet can easily resolve any situation where the states diverged by one
operation on each side. However, in practice, situations can diverge more than this, so
more computation needs to be done.

#### Combining transformed operations

Before moving on to the complex case, let's make the roles of Romeo and Juliet more
specific. In a shared session, we are going to designate one party to be the *client*, and 
the other the *server*. In a one-to-one session such as the one from our example, either party 
can play the client or server role, it just needs to be agreed up front (e.g. the initiator 
of the session). We make this distinction so we can have different focus for the control algorithms
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
Since the *xform* function can only be applied on 2 operations rooted from the same state,
this transformation has to be done in multiple steps. First, *xform* is applied 
on *a* and *c*, yielding *a′* and *c′*; then, *xform* can be applied on *b* and *c′*, in
order to get the desired operation *c′′* rooted on top of Romeo's current state:

                s_0
     .   .   .   o   .   .
                / \ 
             a /   \ c
          s_1 /     \ s_3 (Juliet)
     .   .   o   .   o   .
            / \     //
         b /   \c′ //a′ 
          /     \ //
     .   o   .   o   .   .
     s_2  \     //
        c′′\   //b′
            \ //
     .   .   o   .   .   .
            s_4 (Romeo)

For the future, Romeo remembers the intermediate results *a′* and *b′*; this is exactly the 
combination of operations that would bring Juliet's current state into Romeo's current state.
We refer to this combination as the *bridge* (marked in double lines above).

Before any confirmation on the still pending operation *a* comes in from Juliet, Romeo 
now decides to apply another operation *d* on his whiteboard:

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

Romeo also adds *d* to the *bridge*, memorizing how to get from Juliet's current state to
Romeo's current state:

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
         d // 
          //
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
        c′′\
            \
     .   .   o   .   .   .
            / s_4
         d /
          /
     .   o   .   .   .   .
        s_5 (Romeo)


Again, Romeo needs to transform *e* such that it can be applied on top of his current
state *s<sub>5</sub>*. If we look at the bridge Romeo is keeping, we can see that we
can get to the desired transformed operation *e′′′* by repeatedly applying *xform* on 
all operations along the bridge:

                   
     .   .   .   o   .   .
                / \ 
               /   \ c
              /     \ s_3
     .   .   o   .   o   .
            /       //\
           /    a′ //  \ e
          /       //    \
     .   o   .   o   .   o s_6 (Juliet)
          \   b′//\     /
           \   //  \   / a′′
            \ //  e′\ /
     .   .   o   .   o   .
            //\     /
          d//  \   / b′′
          // e′′\ /
     .   o   .   o   .   .
          \     /
       e′′′\   /d′
            \ /
     .   .   o   .   o   .
            s_7 (Romeo)

Romeo records the intermediate results *a′′*, *b′′*, and *d′* as the new bridge running from 
Juliet's current state to Romeo's current state.

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
        c′ \           / a′′
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

This means Romeo can now remove the first element from his bridge, as it is no longer
required to get from Juliet's current state to his:

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

Since he received confirmation that his operation has been applied, Romeo can now send his
next operation for processing: the version of *b*, transformed such that it is rooted in 
Juliet's history. This is exactly the first element of the bridge, *b′′*.

By maintaining the bridge, and transforming Juliet's operations against it using
repeated invocations of *xform*, Romeo can now keep on processing
Juliet's operations and sending off his own, and make his state converge with Juliet's 
eventually.


#### The Server

So far, we have only focused on Romeo, the client side of the session. Because the client
has the restriction to only send operations rooted in the server's history, it needs to maintain
the entire state space and constantly transform its unprocessed operations before sending the
next one off for processing. 

The server side, however, is much simpler. Since all incoming operations are guaranteed to
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
- A client and a server control algorithm that maintains the state space, and decides which operations
  to transform and to send out for processing. The client algorithm needs to do the heavy lifting
  and an extensive state space, whereas the server algorithm is simple and only needs to maintain a
  very limited history for its transformations.

The rest of this document formalizes these concepts, and also specifies the communication
protocol for a shared session.


### Control Algorithm

Given the operation transformation function 

> xform(a,b) = (a′, b′) such that b′ ○ a ≡ a′ ○ b

The client control algorithm:

    bridge = []
    operation_in_process = false
    current_server_state = "initial"

    on_user_operation_applied(op) :
      bridge.push_back(op)
      if not operation_in_process :
        send_next_operation()

    on_server_operation_received(op) :
      current_server_state = op.target_state
      if op.creator == self :
        new_bridge.pop_front()
        send_next_operation()
      else :
        new_bridge = []
        op_b = op
        for op_a in bridge :
          op_a', op_b' = xform(op_a, op_b)
          new_bridge.push_back(op_a')
          op_b = op_b'
        apply_operation(op_b)
        bridge = new_bridge

    send_next_operation() :
      if bridge.empty() :
        operation_in_process = false
      else :
        op = bridge.front()
        op.source_state = current_server_state 
        op.creator = self
        send_to_server(op)
        operation_in_process = true


The server control algorithm:

    current_state = "initial"
    history = []

    on_operation_received(op) :
      while op.source_state != current_state :
        _, op = xform(history[op.source_state], op)
      current_state = new_id()
      op.target_state = current_state
      history[op.source_state] = op
      send_to_clients(op)


### Whiteboarding

In this section, we describe the concrete operations and transformation functions,
used for applying Operational Transformation on shared whiteboarding sessions.

#### Whiteboarding Operations

The following 3 operations are supported for changing a whiteboarding document:

- `add`: adds an element at a specific location in the document
- `remove`: removes an element from the document
- `update`: updates an element in the document to change its attributes or its position

The `add` and `update` operations take as child payload one of the drawing primitives 
described in [Primitives](#primitives).

#### Insert

The `add` operation has an OPTIONAL `position` attribute to specify where in the document the 
operation is added. If the `operation` attribute is omitted, the element is added at the
end of the document.

For example, suppose the whiteboard document is:

    <rect x="10" y="10" width="100" y2="100"/>
    <line x1="0" y1="0" x2="200" y2="200"/>

Applying the following operation:

    <insert xmlns="urn:xmpp:wb" position="1">
      <ellipsis cx="20" cy="20" rx="30" ry="30"/>
    </insert>

results in the following document:

    <rect x="10" y="10" width="100" y2="100"/>
    <ellipsis cx="20" cy="20" rx="30" ry="30"/>
    <line x1="0" y1="0" x2="200" y2="200"/>

#### Remove

The `remove` operation has a `pos` attribute specifying the offset in the
document of the element to remove.

For example, suppose the whiteboard document is:

    <rect x="10" y="10" width="100" y2="100"/>
    <line x1="0" y1="0" x2="200" y2="200"/>

Applying the following operation:

    <remove xmlns="urn:xmpp:wb" pos="1"/>

results in the following document:

    <rect x="10" y="10" width="100" y2="100"/>


#### Update

The `update` operation contains a `position` attribute to specify the index of
the child element in the document to update, and an OPTIONAL `new-position` 
to specify the new position of the child element. The original element at
position `position` is replaced by the child element of the `update` operation.

For example, suppose the whiteboard document is:

    <rect x="10" y="10" width="100" y2="100"/>
    <ellipsis cx="20" cy="20" rx="30" ry="30"/>
    <line x1="0" y1="0" x2="200" y2="200"/>

Applying the following operation:

    <update xmlns="urn:xmpp:wb" position="1" new-position="2">
      <text x="200" y="200">Hello</text>
    </update>

results in the following document:

    <rect x="10" y="10" width="100" y2="100"/>
    <line x1="0" y1="0" x2="200" y2="200"/>
    <text x="200" y="200">Hello</text>


#### Primitives

The supported drawing primitives are based on a subset from [SVG][].
We list the elements and the attributes that are supported:

- `line`: `stroke`, `stroke-width`, `opacity`, `x1`, `y1`, `x2`, `y2`, 
- `path`: `stroke`, `stroke-width`, `opacity`, `d`
- `rect`: `stroke`, `stroke-width`, `opacity`, `fill`, `fill-opacity`, `x`, `y`, `width`, `height`
- `polygon`: `stroke`, `stroke-width`, `opacity`, `fill`, `fill-opacity`, `points`
- `text`: `opacity`, `x`, `y`, `font-size`, `text`
- `ellipse`: `stroke`, `stroke-width`, `opacity`, `fill`, `fill-opacity`, `cx`, `cy`, `rx`, `ry`


#### Whiteboarding Operation Transformation Function

In this section, we define the transformation function *xform* on all combinations of
the whiteboard operations. For each combination (*client_op*, *server_op*), we give the result
of *xform(client_op, server_op)*.

##### insert(pos1, el1), insert(pos2, el2)

    if pos1 <= pos2 :
      return (insert(pos2 + 1, el2), insert(pos1, el1))
    else :
      return (insert(pos2, el2), insert(pos1 + 1, el1))

##### insert(pos1, el1), remove(pos2)

    if pos1 <= pos2 :
      return (remove(pos2 + 1), insert(pos1, el1))
    else if pos2 != -1 :
      return (remove(pos2), insert(pos1 - 1, el1))
    else :
      return (remove(pos2), insert(pos1, el1))

##### insert(pos1, el1), update(el2, pos2, newpos2)

    if pos2 >= pos1 :
      return (update(pos2 + 1, newpos2, el2), insert(pos1, el1))
    else :
      return (update(pos2, newpos2, el2), insert(pos1, el1))

##### remove(pos1), insert(pos2, el2)

      if op2 <= op1 :
        return (insert(pos2, el2), remove(pos1 + 1))
      else if op1 != -1 :
        return (insert(pos2 - 1, el2), remove(pos1))
      else :
        return (insert(pos2, el2), remove(pos1))
    

##### remove(pos1), remove(pos2)

    if pos1 == -1 or pos2 == -1 :
      return (remove(pos2), remove(pos1))

    if pos1 < pos2 :
      return (remove(pos2 - 1), remove(pos1))
    elif pos2 > pos1
      return (remove(pos2), remove(pos1 - 1))
    else :
      return (remove(-1), remove(-1))
    

##### remove(pos1), update(el2, pos2, newpos2)

    if pos1 == pos2 :
      return (remove(-1), remove(pos1))
    else if pos1 < pos2 and pos1 >= newpos2 :
      return (update(el2, pos2 - 1, newpos2), remove(pos1))
    else if pos1 > pos2 and pos1 <= newpos2 :
      return (update(el2, pos2, newpos2 - 1), remove(pos1))
    else if pos1 < pos2 :
      return (update(el2, pos2 - 1, newpos2 - 1), remove(pos1))
    else :
      return (update(el2, pos2, newpos2), remove(pos1))

##### update(el1, pos1, newpos1), insert(pos2, el2)

    if pos2 <= pos1 :
      return (insert(pos2, el2), update(pos1 + 1, newpos1, el1))
    else :
      return (insert(pos2, el2), update(pos1, newpos1, el1))
  

##### update(el1, pos1, newpos1), remove(pos2)

    if pos1 == pos2 :
      return (remove(pos2), remove(-1))
    else if pos1 > pos2 and newpos1 <= pos2 :
      return (remove(pos2), update(el1, pos1 - 1, newpos1))
    else if pos1 < pos2 and newpos1 >= pos2 :
      return (remove(pos2), update(el1, pos1, newpos1 - 1))
    else if pos1 > pos2 :
      return (remove(pos2), update(el1, pos1 - 1, newpos1 - 1))
    else :
      return (remove(pos2), update(el1, pos1, newpos1))
    

##### update(el1, pos1, newpos1), update(el2, pos2, newpos2)

    if pos1 < pos2 and newpos1 > newpos2 :
      op2' = update(el2, pos2 - 1, newpos2); 
    else if pos1 < pos2 and newpos1 >= newpos2 :
      op2' = update(el2, pos2 - 1, newpos2 - 1); 
    else if pos1 >= pos2 and newpos1 >= newpos2 : 
      op2' = update(el2, pos2, newpos2-1); 
    else :
      op2' = update(el2, pos2, newpos2);

    if pos2 < pos1 and newpos2 > newpos1 :
      op1' = update(el1, pos1 - 1, newpos1); 
    else if pos2 < pos1 and newpos2 >= newpos1 :
      op1' = update(el1, pos1 - 1, newpos1 - 1); 
    else if pos2 >= pos1 and newpos2 >= newpos1 :
      op1' = update(el1, pos1, newpos1 - 1); 
    else :
      op1' = update(el1, pos1, newpos1)

    return (op2', op1')
    

## Use Cases

### Session Initialization
    
When an entity wants to start a whiteboarding session with another entity, it sends
a `session-request` query to the other party, with a whiteboarding `description`
element.

*Example: Initiator requests a new shared text editing session*

    <iq from="romeo@montague.net/garden"
        to="juliet@capulet.com/balcony"
        type="set" id="request-1">
      <session-request xmlns="urn:xmpp:shedit" sid="session1">
        <description xmlns="urn:xmpp:wb">
          <desc>Would you mind drawing with me?</desc>
        </description>
      </session-request>
    </iq>

The other party immediately acknowledges receipt of the request.

*Example: Responder acknowledges receipt of the request*

    <iq from="juliet@capulet.com/balcony"
        to="romeo@montague.net/garden"
        type="result" id="request-1">
    </iq>

When the other party agrees to do a whiteboard session, it sends a 
`session-accept` element, and the initiator immediately acknowledges receipt.

*Example: Responder accepts request*

    <iq from="juliet@capulet.com/balcony"
        to="romeo@montague.net/garden"
        type="set" id="accept-1">
      <session-accept xmlns="urn:xmpp:shedit" sid="session1"/>
    </iq>

*Example: Initiator acknowledges receipt of the acceptance*

    <iq from="romeo@montague.net/garden"
        to="juliet@capulet.com/balcony"
        type="result" id="accept-1">
      <session-request xmlns="urn:xmpp:shedit" sid="session1">
        <wb xmlns="urn:xmpp:wb"/>
      </session-request>
    </iq>

After this exchange, the whiteboard session has started, and parties can start sending
each other operations.

Alternatively, if the responding entity does not want to start a whiteboarding session, it 
rejects the request with a `session-terminate` request.

*Example: Responder rejects request*

    <iq to="juliet@capulet.com/balcony"
        from="romeo@montague.net/garden"
        type="set" id="accept-1">
      <session-terminate xmlns="urn:xmpp:shedit" sid="session1"/>
    </iq>
    

### Session Termination

During a whiteboarding session, either entity can terminate the session by sending a
terminate request.

*Example: Session is terminated by an entity*

    <iq to="juliet@capulet.com/balcony"
        from="romeo@montague.net/garden"
        type="set">
      <session-terminate xmlns="urn:xmpp:shedit" sid="session1"/>
    </iq>
  

### Exchanging operations

During a whiteboarding session, entities send each other operations that have been applied to
their local whiteboard. These operations need to applied locally, possibly after first being
transformed using the *operational transformation* algorithms described in 
[Control Algorithm](#control-algorithm).
The initiator of the session follows the *client* algorithm for transforming operations,
whereas the responder follows the *server* algorithm.


#### Server sends operations to Client

The server always keeps the state of the whiteboard locally. Whenever the server
applies an operation on the whiteboard (either an operation received from the client, or
an operation from someone controlling the server), it sends out a notification to the
connected client. The applied operation and its data are wrapped in an `operation` element.
Additionally, the `operation` element has a `creator` attribute containing the full JID
of the originator of the operation (i.e. either the server or the client), and a
`target-state` attribute containing an identifier that the server uses to identify the
new state of the whiteboard.

*Example: Server sends operation to client*

    <iq from="juliet@capulet.com/balcony"
        to="romeo@montague.net/garden"
        type="set" id="operation-2">
      <operation xmlns="urn:xmpp:shedit" sid="session1" target-state="state-5"
                 creator="juliet@capulet.com/balcony">
        <insert xmlns="urn:xmpp:wb">
          <line x1="0" y1="0" x2="200" y2="200"/>
        </insert>
      </operation>
    </iq>

When the client receives the operation, it immediately acknowledges receipt of the operation.

*Example: Client acknolwedges receipt of operation*

    <iq from="romeo@montague.net/garden"
        to="juliet@capulet.com/balcony"
        type="result" id="operation-2">
    </iq>

If the client receives an operation that was not originated from itself (i.e.
it has a different `creator` JID), the client needs to apply the incoming
operation to its own local version of the whiteboard.  If the client has any
operations applied on its whiteboard that have not yet been processed by the
server (i.e. that have not yet been sent back as an `operation` from the server), it 
needs to first transform the received operation such that
it is applicable to the current state of the whiteboard. This is done using
(possibly multiple applications of) the *xform* function, as described in the
client algorithm from [Control Algorithm](#control-algorithm).


#### Client sends operations to Server

Similarly to the server, the client also keeps the state of the whiteboard locally.
When the entity controlling the client has applied an operation on the whiteboard, it 
sends this operation to the server. This is done by wrapping the exact operation and its data
in an `operation` element, with a `source-state` attribute to indicate the 
server state on which this operation is rooted. This attribute MUST correspond to the 
last received `target-state` value of an operation received from the server. If no operation 
has been received from the server yet, the `source-state` attribute MUST be omitted.

*Example: Client sends operation to server*

    <iq from="romeo@montague.net/garden"
        to="juliet@capulet.com/balcony"
        type="set" id="operation-4">
      <operation xmlns="urn:xmpp:shedit" sid="session1" source-state="state-2">
        <insert xmlns="urn:xmpp:wb">
          <line x1="100" y1="100" x2="300" y2="300"/>
        </insert>
      </operation>
    </iq>

The server immediately acknowledges receipt of the operation.

*Example: Server acknowledges receipt of the operation*

    <iq from="juliet@capulet.com/balcony"
        to="romeo@montague.net/garden"
        type="result" id="operation-4">
    </iq>

When a client has sent an operation, it MUST wait for a notification of the corresponding 
operation applied on the server side before sending any other locally applied operations.

When the server receives an operation, it applies it to its local whiteboard. If the
`source-state` of the operation is not the most current state, the server first needs to 
transform the operation using the OT algorithm described in [Control Algorithm](#control-algorithm), 
such that it is rooted 
in the most current state. After it has applied this operation, it sends a corresponding operation
back, with the `target-state` attribute set to a new identifier for a state, and
the `creator` set to the full JID of the originator of the operation. Since the `source-state`
is implictly known (it is the same as the `target-state` of the last operation), it can be
omitted.

*Example: Server sends corresponding operation*

    <iq from="juliet@capulet.com/balcony"
        to="romeo@montague.net/garden"
        type="set" id="operation-23">
      <operation xmlns="urn:xmpp:shedit" sid="session1" target-state="state-5"
                 creator="romeo@montague.net/garden">
        <insert xmlns="urn:xmpp:wb">
          <line x1="200" y1="200" x2="300" y2="300"/>
        </insert>
      </operation>
    </iq>

From the `creator` attribute, the client knows when its operation has been applied.



<!--
    
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

<!--
## Implementation Notes
 
OPTIONAL

## Accessibility Considerations

OPTIONAL.

## Internationalization Considerations

OPTIONAL.

-->

## Security Considerations

## IANA Considerations

This document requires no interaction with [IANA][]

## XMPP Registrar Considerations

The [XMPP Registrar][] includes `urn:xmpp:shedit` and `urn:xmpp:wb` in its registry of 
protocol namespaces (see <http://xmpp.org/registrar/namespaces.html>).

## XML Schemas

### urn:xmpp:shedit

    <?xml version='1.0' encoding='UTF-8'?>

    <xs:schema
        xmlns:xs='http://www.w3.org/2001/XMLSchema'
        targetNamespace='urn:xmpp:shedit'
        xmlns='urn:xmpp:shedit'
        elementFormDefault='qualified'>

      <xs:annotation>
        <xs:documentation>
          The protocol documented by this schema is defined in
          XEP-???: http://www.xmpp.org/extensions/xep-???.html
        </xs:documentation>
      </xs:annotation>

      <xs:element name='session-request'>
        <xs:complexType>
          <xs:choice>
            <xs:any namespace='##other'/>
          </xs:choice>
          <xs:attribute name='sid' type='xs:string' use='required'/>
        </xs:complexType>
      </xs:element>

      <xs:element name='session-accept'>
        <xs:complexType>
          <xs:simpleContent>
            <xs:extension base='empty'>
              <xs:attribute name='sid' type='xs:string' use='required'/>
            </xs:extension>
          </xs:simpleContent>
        </xs:complexType>
      </xs:element>

      <xs:element name='session-terminate'>
        <xs:complexType>
          <xs:attribute name='sid' type='xs:string' use='required'/>
        </xs:complexType>
      </xs:element>

      <xs:element name='operation'>
        <xs:complexType>
          <xs:choice>
            <xs:any namespace='##other'/>
          </xs:choice>
          <xs:attribute name='sid' type='xs:string' use='required'/>
          <xs:attribute name='source-state' type='xs:string' use='optional'/>
          <xs:attribute name='target-state' type='xs:string' use='optional'/>
          <xs:attribute name='creator' type='xs:string' use='optional'/>
        </xs:complexType>
      </xs:element>

      <xs:simpleType name='empty'>
        <xs:restriction base='xs:string'>
          <xs:enumeration value=''/>
        </xs:restriction>
      </xs:simpleType>

    </xs:schema>


### urn:xmpp:wb

    <?xml version='1.0' encoding='UTF-8'?>

    <xs:schema
        xmlns:xs='http://www.w3.org/2001/XMLSchema'
        targetNamespace='urn:xmpp:wb'
        xmlns='urn:xmpp:wb'
        elementFormDefault='qualified'>

      <xs:annotation>
        <xs:documentation>
          The protocol documented by this schema is defined in
          XEP-???: http://www.xmpp.org/extensions/xep-???.html
        </xs:documentation>
      </xs:annotation>

      <xs:element name='description'>
        <xs:complexType>
          <xs:sequence>
            <xs:element name='desc' type='xs:string'/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>

      <xs:element name='add'>
        <xs:complexType>
          <xs:choice>
            <xs:element ref='line'/>
            <xs:element ref='path'/>
            <xs:element ref='rect'/>
            <xs:element ref='polygon'/>
            <xs:element ref='text'/>
            <xs:element ref='ellipse'/>
          </xs:choice>
        </xs:complexType>
      </xs:element>

      <xs:element name='remove'>
        <xs:complexType>
          <xs:choice>
            <xs:element ref='line'/>
            <xs:element ref='path'/>
            <xs:element ref='rect'/>
            <xs:element ref='polygon'/>
            <xs:element ref='text'/>
            <xs:element ref='ellipse'/>
          </xs:choice>
        </xs:complexType>
      </xs:element>

      <xs:element name='update'>
        <xs:complexType>
          <xs:choice>
            <xs:element ref='line'/>
            <xs:element ref='path'/>
            <xs:element ref='rect'/>
            <xs:element ref='polygon'/>
            <xs:element ref='text'/>
            <xs:element ref='ellipse'/>
          </xs:choice>
        </xs:complexType>
      </xs:element>

      <xs:element name='line'>
        <xs:complexType>
          <xs:simpleContent>
            <xs:extension base='empty'>
              <xs:attribute name='id' type='xs:string' use='required'/>
              TODO
            </xs:extension>
          </xs:simpleContent>
        </xs:complexType>
      </xs:element>
      
      TODO: Primitives

      <xs:simpleType name='empty'>
        <xs:restriction base='xs:string'>
          <xs:enumeration value=''/>
        </xs:restriction>
      </xs:simpleType>

    </xs:schema>

## Acknolwedgements

The introductory example from this specification is based on 
[Understanding and Applying Operational Transformation][ot-intro].


[ot-intro]: http://www.codecommit.com/blog/java/understanding-and-applying-operational-transformation]
[SVG]: http://www.w3.org/TR/SVGMobile12/ "Scalable Vector Graphics (SVG) Tiny 1.2 Specification"
[IANA]: ...
[XMPP Registrar]: ...
