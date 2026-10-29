// Disposable folklore thread, not a canonical quest.
VAR reported_basin = false
VAR found_passage = false
VAR found_dry_basin = false
VAR has_delivery = false
VAR finished_delivery = false
-> greeting
=== greeting ===
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
+ {not has_delivery && not finished_delivery} [Ask for a small delivery.]
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
=== farewell ===
+ [Thank him and leave.]
    -> END
