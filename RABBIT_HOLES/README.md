# RabbitHoles

## Idea:
- Use cairo/starknet
- Start permanent discussion threads for any topic
- Store comments in these discussion threads

## Terminology
- These discussion threads are called `holes`
- The messages in them are called `rabbits`

## Holes
A hole is made of 4 members. Its `digger`, `title`, `timestamp`, and `rabbit_count`
- The `digger` is the account that started the discussion thread
- The `title` is a felt representation for the title
  - Each title must be < 32 characters
- The `timestamp` is the block timestamp when the hole was dug
- The `rabbit count` is the number of rabbits/comments within the hole
  - This is used for indexing specific rabbits within a specific hole 

## Rabbits
A rabbit is made of 5 members. Its `leaver`, `timestamp`, `hole_index`, `comment_stack_start`, and `comment_stack_len`
- The `leaver` is the account that left the rabbit
- The `timestamp` is the block timestamp when the rabbit was left
- The `hole_index` is the index for the hole this rabbit belongs to
- The `comment_stack_start` and `comment_stack_len` are used to retrieve the rabbit's comment (see below)

## The Comment Stack
Because a rabbit's comment can be any length of characters, a comment is divided into its comment chunks (each a `felt`). The `comment_stack_start` for a rabbit tells where on the comment_stack the specific rabbit's comment starts, and the `comment_stack_len` tells how many comment chunks this rabbit's comment fills

## Technicals
- The frontend application will handle `str` & `felt` conversions
- An account will be minted a few RBIT when they dig a hole
- Rabbits can only be left in already dug holes
- When leaving a rabbit in a hole the caller will burn 1 `RBIT`

## Future
- Later there will be a fee for digging each `hole`
  - This will discourage hole dig spamming by introducing a pay wall

## Currently
- Testing the contract
- Building the frontend 
