# RabbitHoles

## Idea:
- Start permanent discussion threads for any topic
- Leave permanent messages in these discussion threads

## Terminology
- These discussion threads are called `holes`
- The messages in them are called `rabbits`

## Technicals
- A hole is represented by its title (in the form of a felt)
  - Meaning each title can only be < 32 characters
  - The frontend application will handle string -> felt conversion
- An account will be minted RBIT when they dig a hole
- Rabbits can only be left in already dug holes
- When leaving a rabbit in a hole the caller will burn 1 RBIT
- A rabbit's comment can be any number of character long
  - The front end application will convert a user's string into a felt* for storing
- Later there will be a fee for digging a hole
  - This will reduce hole digging spam by introducing a pay wall
