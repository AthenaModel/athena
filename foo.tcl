# Exporting unsaved scenario from current data
# Exported @ Mon Feb 23 14:53:40 PST 2015
# Written by Athena version 6.3.0a5
#
# Note: if header has no commands following it, then
# there was no data of that kind to export.

#-----------------------------------------------------------------
# Date and Time Parameters

send SIM:STARTDATE -startdate 2012W01
send SIM:STARTTICK -starttick 0

#-----------------------------------------------------------------
# Model Parameters


#-----------------------------------------------------------------
# Map and Projection


#-----------------------------------------------------------------
# Belief Systems

send BSYS:PLAYBOX:UPDATE -gamma .7
send BSYS:TOPIC:ADD -tid 1
send BSYS:TOPIC:UPDATE -tid 1 -name {Peonian Independence} -affinity 1
send BSYS:TOPIC:ADD -tid 2
send BSYS:TOPIC:UPDATE -tid 2 -name Democracy -affinity 1
send BSYS:TOPIC:ADD -tid 3
send BSYS:TOPIC:UPDATE -tid 3 -name Patriotism -affinity 0
send BSYS:TOPIC:ADD -tid 4
send BSYS:TOPIC:UPDATE -tid 4 -name Puppies! -affinity 0

send BSYS:SYSTEM:ADD -sid 2
send BSYS:SYSTEM:UPDATE -sid 2 -name GOV -commonality 1.0
send BSYS:BELIEF:UPDATE -bid {2 1} -position -0.6 -emphasis .25
send BSYS:BELIEF:UPDATE -bid {2 2} -position -0.6 -emphasis .25

send BSYS:SYSTEM:ADD -sid 3
send BSYS:SYSTEM:UPDATE -sid 3 -name PELF -commonality .8
send BSYS:BELIEF:UPDATE -bid {3 1} -position .9 -emphasis .15
send BSYS:BELIEF:UPDATE -bid {3 2} -position .3 -emphasis .7

send BSYS:SYSTEM:ADD -sid 4
send BSYS:SYSTEM:UPDATE -sid 4 -name EPP -commonality 1.0
send BSYS:BELIEF:UPDATE -bid {4 1} -position .3 -emphasis .35
send BSYS:BELIEF:UPDATE -bid {4 2} -position .6 -emphasis .15

send BSYS:SYSTEM:ADD -sid 5
send BSYS:SYSTEM:UPDATE -sid 5 -name PEONR -commonality .6
send BSYS:BELIEF:UPDATE -bid {5 1} -position .6 -emphasis .25
send BSYS:BELIEF:UPDATE -bid {5 2} -position .3 -emphasis .7

send BSYS:SYSTEM:ADD -sid 6
send BSYS:SYSTEM:UPDATE -sid 6 -name PEONU -commonality .45
send BSYS:BELIEF:UPDATE -bid {6 1} -position .6 -emphasis .35
send BSYS:BELIEF:UPDATE -bid {6 2} -position .6 -emphasis .7

send BSYS:SYSTEM:ADD -sid 7
send BSYS:SYSTEM:UPDATE -sid 7 -name ELR -commonality 1.0
send BSYS:BELIEF:UPDATE -bid {7 1} -position -0.9 -emphasis .25
send BSYS:BELIEF:UPDATE -bid {7 2} -position .3 -emphasis .7

send BSYS:SYSTEM:ADD -sid 8
send BSYS:SYSTEM:UPDATE -sid 8 -name ELU -commonality 1.0
send BSYS:BELIEF:UPDATE -bid {8 1} -position -0.9 -emphasis .15
send BSYS:BELIEF:UPDATE -bid {8 2} -position -0.3 -emphasis .35

send BSYS:SYSTEM:ADD -sid 9
send BSYS:SYSTEM:UPDATE -sid 9 -name SA -commonality 1.0

send BSYS:SYSTEM:ADD -sid 10
send BSYS:SYSTEM:UPDATE -sid 10 -name NOBODY -commonality 1.0

send BSYS:SYSTEM:ADD -sid 11
send BSYS:SYSTEM:UPDATE -sid 11 -name ICS -commonality 1.0

#-----------------------------------------------------------------
# Base Entities: Actors

send ACTOR:CREATE -a GOV -longname {Elitian Government} -bsid 2 -auto_maintain 0 -atype INCOME -cash_reserve 0.00 -cash_on_hand 0.00 -income_goods 5.000M -shares_black_nr 0 -income_black_tax 0.00 -income_pop 0.00 -income_graft 0.00 -income_world 0.00 -budget 0.00
send ACTOR:CREATE -a PELF -longname {Peonian Liberation Front} -bsid 3 -auto_maintain 0 -atype INCOME -cash_reserve 0.00 -cash_on_hand 500,000 -income_goods 250,000 -shares_black_nr 1 -income_black_tax 0.00 -income_pop 0.00 -income_graft 0.00 -income_world 0.00 -budget 0.00
send ACTOR:CREATE -a EPP -longname {Elitian People's Party} -bsid 4 -auto_maintain 0 -atype INCOME -cash_reserve 0.00 -cash_on_hand 0.00 -income_goods 1.000M -shares_black_nr 0 -income_black_tax 0.00 -income_pop 0.00 -income_graft 0.00 -income_world 0.00 -budget 0.00
send ACTOR:SUPPORTS -a GOV -supports SELF
send ACTOR:SUPPORTS -a PELF -supports SELF
send ACTOR:SUPPORTS -a EPP -supports SELF

#-----------------------------------------------------------------
# Base Entities: Neighborhoods

send NBHOOD:CREATE -n CITY -longname {Capital City} -local YES -pcf { 1.0} -urbanization URBAN -controller GOV -refpoint 38TNL8520188993 -polygon {38TNM5042915758 38TPM4232815661 38TPL3404250197 38TNL4582553998}
send NBHOOD:CREATE -n EL -longname Elitia -local YES -pcf { 1.0} -urbanization RURAL -controller GOV -refpoint 38TPL7604885303 -polygon {38TPM4232815661 38TQM4307507697 38TQK3834390612 38TNL8468203274 38TPL3404250197}
send NBHOOD:CREATE -n PE -longname Peonia -local YES -pcf { 1.0} -urbanization RURAL -controller GOV -refpoint 38TNL5764723441 -polygon {38TNL4582553998 38TNL0862002796 38TNK9116028747 38TNL8468203274 38TPL3404250197}
send NBHOOD:CREATE -n IN -longname Incognitia -local NO -pcf { 0.0} -urbanization RURAL -controller NONE -refpoint 38TPK5236867484 -polygon {38TNL8468203274 38TQK3834390612 38SQK2677118249 38TNK9116028747}
send NBREL:UPDATE -id {EL CITY} -proximity NEAR
send NBREL:UPDATE -id {CITY EL} -proximity FAR
send NBREL:UPDATE -id {PE CITY} -proximity REMOTE
send NBREL:UPDATE -id {PE EL} -proximity FAR
send NBREL:UPDATE -id {CITY PE} -proximity REMOTE
send NBREL:UPDATE -id {EL PE} -proximity FAR
send NBREL:UPDATE -id {IN CITY} -proximity REMOTE
send NBREL:UPDATE -id {IN EL} -proximity REMOTE
send NBREL:UPDATE -id {IN PE} -proximity REMOTE
send NBREL:UPDATE -id {CITY IN} -proximity REMOTE
send NBREL:UPDATE -id {EL IN} -proximity REMOTE
send NBREL:UPDATE -id {PE IN} -proximity REMOTE

#-----------------------------------------------------------------
# Base Entities: Civilian Groups

send CIVGROUP:CREATE -g PEONR -longname {Rural Peons} -n PE -bsid 5 -color #AA7744 -demeanor AGGRESSIVE -basepop 800000 -pop_cr 0.0 -sa_flag 0 -lfp 60 -housing AT_HOME -hist_flag 0 -upc 0.0
send CIVGROUP:CREATE -g PEONU -longname {Urban Peons} -n CITY -bsid 6 -color #AA7744 -demeanor AVERAGE -basepop 50000 -pop_cr 0.0 -sa_flag 0 -lfp 60 -housing AT_HOME -hist_flag 0 -upc 0.0
send CIVGROUP:CREATE -g ELR -longname {Rural Elitians} -n EL -bsid 7 -color #45DD11 -demeanor AVERAGE -basepop 600000 -pop_cr 0.0 -sa_flag 0 -lfp 60 -housing AT_HOME -hist_flag 0 -upc 0.0
send CIVGROUP:CREATE -g ELU -longname {Urban Elitians} -n CITY -bsid 8 -color #45DD11 -demeanor AVERAGE -basepop 300000 -pop_cr 0.0 -sa_flag 0 -lfp 60 -housing AT_HOME -hist_flag 0 -upc 0.0
send CIVGROUP:CREATE -g SA -longname SA -n PE -bsid 9 -color #45DD11 -demeanor AVERAGE -basepop 100000 -pop_cr 0.0 -sa_flag 1 -lfp 0 -housing AT_HOME -hist_flag 0 -upc 0.0
send CIVGROUP:CREATE -g NOBODY -longname NOBODY -n CITY -bsid 10 -color #45DD11 -demeanor AVERAGE -basepop 0 -pop_cr 0.0 -sa_flag 0 -lfp 60 -housing AT_HOME -hist_flag 0 -upc 0.0
send CIVGROUP:CREATE -g ICS -longname Incognitians -n IN -bsid 11 -color #45DD11 -demeanor AVERAGE -basepop 10000 -pop_cr 0.0 -sa_flag 0 -lfp 60 -housing AT_HOME -hist_flag 0 -upc 0.0

#-----------------------------------------------------------------
# Base Entities: Force Groups

send FRCGROUP:CREATE -g ARMY -longname {Elitian Army} -a GOV -color #3B61FF -forcetype REGULAR -training FULL -base_personnel 20000 -demeanor AVERAGE -cost 0.00 -local 1
send FRCGROUP:CREATE -g PELFM -longname {PELF Militia} -a PELF -color #3B61FF -forcetype IRREGULAR -training FULL -base_personnel 6000 -demeanor AGGRESSIVE -cost 1,000.00 -local 1

#-----------------------------------------------------------------
# Base Entities: Organization Groups

send ORGGROUP:CREATE -g PAL -longname {Peonian Assistance League} -a PELF -color #B300B3 -orgtype NGO -base_personnel 1000 -demeanor AVERAGE -cost 0.00

#-----------------------------------------------------------------
# Attitudes


#-----------------------------------------------------------------
# Abstract Situations

send ABSIT:CREATE -n EL -stype COMMOUT -coverage 1.0000 -inception 1 -resolver NONE -rduration 1

#-----------------------------------------------------------------
# Economics: SAM Inputs


#-----------------------------------------------------------------
# Plant Infrastructure:

send PLANT:SHARES:CREATE -a GOV -n CITY -rho 1.0 -num 1
send PLANT:SHARES:CREATE -a GOV -n EL -rho 1.0 -num 1

#-----------------------------------------------------------------
# CURSEs

send CURSE:CREATE -curse_id FLOOD -longname {Flood in Peonia} -cause UNIQUE -s 1.0 -p 0.5 -q 0.1
send CURSE:CREATE -curse_id FIRE -longname {Fire in Elitia} -cause UNIQUE -s 1.0 -p 0.2 -q 0.05
send INJECT:COOP:CREATE -curse_id FLOOD -mode transient -f @CIV1 -g @FRC1 -mag 1.0
send INJECT:HREL:CREATE -curse_id FLOOD -mode transient -f @FRC1 -g @CIV1 -mag -11.0
send INJECT:SAT:CREATE -curse_id FLOOD -mode transient -g @CIV2 -c SFT -mag -4.5
send INJECT:SAT:CREATE -curse_id FIRE -mode transient -g @CIVGRP2 -c QOL -mag -10.5
send INJECT:VREL:CREATE -curse_id FLOOD -mode transient -g @GRP1 -a @ACT1 -mag -8.0

#-----------------------------------------------------------------
# Communication Asset Packages (CAPs)

send CAP:CREATE -k CBS -longname {Corps Broadcasting System} -owner GOV -capacity 1.0 -cost 100.0
send CAP:CREATE -k FOX -longname {Fox Snooze} -owner PELF -capacity 0.9 -cost 20.0
send CAP:NBCOV:SET -id {CBS CITY} -nbcov 1.00
send CAP:NBCOV:SET -id {CBS EL} -nbcov 1.00
send CAP:NBCOV:SET -id {FOX EL} -nbcov 1.00
send CAP:NBCOV:SET -id {FOX PE} -nbcov 1.00
send CAP:PEN:SET -id {CBS ELR} -pen 1.00
send CAP:PEN:SET -id {CBS ELU} -pen 1.00
send CAP:PEN:SET -id {FOX PEONR} -pen 1.00
send CAP:PEN:SET -id {FOX ELR} -pen 1.00

#-----------------------------------------------------------------
# Semantic Hooks

send HOOK:CREATE -hook_id PUPGOOD -longname {Puppies Are Good!}
send HOOK:CREATE -hook_id HPAT -longname {Patriotism and Puppies}
send HOOK:TOPIC:CREATE -hook_id PUPGOOD -topic_id 4 -position 0.6
send HOOK:TOPIC:CREATE -hook_id HPAT -topic_id 3 -position 0.6
send HOOK:TOPIC:CREATE -hook_id HPAT -topic_id 4 -position 0.9

#-----------------------------------------------------------------
# Information Operations Messages (IOMs)

send IOM:CREATE -iom_id NOPUPPIES -longname {The Gov't wants to eat our puppies.} -hook_id PUPGOOD
send IOM:CREATE -iom_id PATRIOT -longname {Be a patriot! Support our puppies!} -hook_id HPAT
send PAYLOAD:COOP:CREATE -iom_id NOPUPPIES -g ARMY -mag -8.5
send PAYLOAD:HREL:CREATE -iom_id PATRIOT -g ARMY -mag 7.0
send PAYLOAD:VREL:CREATE -iom_id PATRIOT -a GOV -mag 13.0

#-----------------------------------------------------------------
# Strategy: EPP


#-----------------------------------------------------------------
# Strategy: GOV

block add GOV -onlock 1 -once 0 -name B1 -intent {Deploy Troops} -tmode ALWAYS -t1 {} -t2 {} -cmode ALL -emode ALL
tactic add - DEPLOY -name T1 -g ARMY -pmode ALL -personnel 0 -min 0 -max 0 -percent 0 -nlist {_type NBHOODS _rule BY_VALUE nlist CITY alist {} anyall {} glist {}} -nmode BY_POP -redeploy 0
tactic add - ASSIGN -name T2 -g ARMY -n CITY -activity PATROL -pmode SOME -personnel 100 -min 0 -max 0 -percent .0

block add GOV -onlock 0 -once 0 -name B2 -intent {Build Infrastructure} -tmode ALWAYS -t1 {} -t2 {} -cmode ALL -emode ALL
tactic add - BUILD -name T1 -n CITY -mode CASH -num 1 -amount 100000.0


#-----------------------------------------------------------------
# Strategy: PELF

block add PELF -onlock 1 -once 0 -name B1 -intent {Deploy ORG} -tmode ALWAYS -t1 {} -t2 {} -cmode ALL -emode ALL
tactic add - DEPLOY -name T1 -g PAL -pmode ALL -personnel 0 -min 0 -max 0 -percent 0 -nlist {_type NBHOODS _rule BY_VALUE nlist PE alist {} anyall {} glist {}} -nmode BY_POP -redeploy 0


#-----------------------------------------------------------------
# Strategy: SYSTEM


#-----------------------------------------------------------------
# Executive Scripts


# *** End of Script ***
