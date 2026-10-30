VAR missed_delivery = false
VAR cancelled_delivery = false
VAR acknowledged_delivery = false
VAR eligible_favor = false
VAR has_favor = false
VAR finished_favor = false
// Disposable folklore thread, not a canonical quest.
VAR reported_basin = false
VAR found_passage = false
VAR found_dry_basin = false
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
{reported_basin:
The merchant turns a cracked cup in his hands. "You told me the spring has fallen silent. I should stop promising thirsty travelers a drink."
- else:
The merchant shades his stall with a woven cloth. "A little honest work leaves the evening free for wonders."
}
+ [Ask about the old workshop.]
    {found_passage:
    "You found the side passage yourself? Then you know more than the men who sell directions to it."
    - else:
    "They say a narrow passage beyond the workshop leads to a spring that sings after sunset. I heard it from a boatman; I have never tasted its water."
    }
    # command:passage_rumor
    {not reported_basin:
    # command:water_rumor
    }
    -> farewell
+ {not has_delivery && not finished_delivery && not missed_delivery && not cancelled_delivery} [Ask for a small delivery.]
    "The courier needs provisions. Bring the agreed goods before the deadline; the payment is set aside."
    # command:accept_provisions
    -> farewell
+ {has_delivery} [Discuss the provisions delivery.]
    "Find the courier during working hours. The workshop bench is yours to use, but a deadline waits for no oven."
    -> farewell
+ {finished_delivery} [Mention the completed delivery.]
    "The courier spoke well of you. Reliable hands are worth more than loud promises."
    -> farewell
+ [Leave the merchant to his work.]
    -> END
+ {found_dry_basin && not reported_basin} [Report the dry basin you inspected.]
    "Dust in the channel, you say? Then I owe that boatman a question. I will tell travelers to carry their own water. Thank you for checking instead of repeating me."
    # command:report_basin
    -> farewell
+ {has_delivery} [Tell him you cannot keep the delivery commitment.]
    "Better to warn me than leave the courier waiting. I will release the reserved payment. We can still trade as neighbors."
    # command:cancel_provisions
    -> farewell
+ {(missed_delivery || cancelled_delivery) && not acknowledged_delivery} [Acknowledge the broken delivery commitment.]
    "Thank you for saying so. I remember the missed parcel, but an honest word matters. There is no fine and no door closed to you."
    # command:acknowledge_provisions
    -> farewell
+ {eligible_favor} [Ask if your reliable help has earned another small favor.]
    "You kept your word on the provisions. Could you take four measures of grain to the courier as well? This is optional; the usual trade remains open."
    # command:accept_favor
    -> farewell
+ {finished_favor} [Mention the grain favor.]
    "Two commitments kept. I know whose hands I can trust with a small errand."
    -> farewell
=== farewell ===
+ [Thank him and leave.]
    -> END
