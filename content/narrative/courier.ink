VAR missed_delivery = false
VAR cancelled_delivery = false
VAR acknowledged_delivery = false
VAR eligible_favor = false
VAR has_favor = false
VAR finished_favor = false
// Disposable second perspective; world and Work stay authoritative.
VAR found_dry_basin = false
VAR reported_basin = false
VAR has_delivery = false
VAR finished_delivery = false
-> greeting
=== greeting ===
{missed_delivery:
    {acknowledged_delivery: "We have spoken about the missed delivery. Let us leave the account honest."|"I remember waiting for the provisions. What happened?"}
}
{cancelled_delivery:
    "The provisions delivery was called off. There is still ordinary work and conversation to be had."
}
{finished_delivery:
The courier tightens the straps on the provision pack. "Safe in my hands. Your payment has already been released."
- else:
The courier rests beside a folded sail. "A story travels quickly. A parcel still needs someone to carry it."
}
+ {has_delivery} [Hand over the agreed provisions.]
    "Two packs, just as promised. I can leave before the shade moves. Here is your agreed payment."
    # command:deliver_provisions
    -> goodbye
+ {found_dry_basin} [Discuss the dry basin beyond the workshop.]
    {reported_basin:
    "Good that you warned the merchant. We can carry water rather than chase a song."
    - else:
    "Then tell the merchant what you saw. He repeats that boatman's story to everyone who asks."
    }
    -> goodbye
+ [Ask about the courier's day.]
    "Provisions before the afternoon road; a little shade afterward. Ask the merchant if you want paid work."
    -> goodbye
+ [Say farewell.]
    -> END
+ {(missed_delivery || cancelled_delivery) && not acknowledged_delivery} [Acknowledge the parcel that never came.]
    "I had to leave without it. Thank you for facing me about it. We can share the shade without pretending the parcel arrived."
    # command:acknowledge_provisions
    -> goodbye
+ {has_favor} [Hand over the grain favor.]
    "Four measures, all here. You have helped twice now. The merchant's payment is yours."
    # command:deliver_favor
    -> goodbye
=== goodbye ===
+ [Leave the courier to the road.]
    -> END
