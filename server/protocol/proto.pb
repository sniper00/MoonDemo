
‡
center.proto"

C2SMatch"
S2CMatch
res (Rres"
S2CMatchSuccess"#
S2CGameOver
score (RscoreBª
NetMessagebproto3
³
common.proto"%
Vector2
x (Rx
y (Ry"0
ItemData
id (Rid
count (Rcount"²
MailData
id (Rid
mail_key (	RmailKey
ctime (Rctime
flag (Rflag#
rewards (2	.ItemDataRrewards
trace (Rtrace
parmas (	RparmasBª
NetMessagebproto3
ë

mail.protocommon.proto"
C2SMailList"Ž
S2CMailList7
	mail_list (2.S2CMailList.MailListEntryRmailListF
MailListEntry
key (Rkey
value (2	.MailDataRvalue:8"7
S2CUpdateMail&
	mail_list (2	.MailDataRmailList"
C2SMailRead
id (Rid"
C2SMailLock
id (Rid"1
C2SMailReward 
mail_id_list (R
mailIdList"
C2SMailMark
id (Rid".

C2SMailDel 
mail_id_list (R
mailIdList".

S2CMailDel 
mail_id_list (R
mailIdListbproto3
ô

room.protocommon.proto""
C2SEnterRoom
name (	Rname"2
S2CEnterRoom
id (Rid
time (Rtime"%
C2SMove
x (Rx
y (Ry"y
S2CMove
id (Rid
x (Rx
y (Ry
dirx (Rdirx
diry (Rdiry
movetime (Rmovetime"Ð
S2CEnterView
id (Rid
x (Rx
y (Ry
radius (Rradius
spriteid (Rspriteid
speed (Rspeed
dir (2.Vector2Rdir
name (	Rname
movetime	 (Rmovetime"
S2CLeaveView
id (Rid"9
S2CUpdateRadius
id (Rid
radius (Rradius"
S2CDead
id (RidBª
NetMessagebproto3
û

user.protocommon.proto""
S2CErrorCode
code (Rcode""
C2SLogin
openid (	Ropenid"J
S2CLogin
ok (Rok
time (Rtime
timezone (Rtimezone"
C2SItemList"}
S2CItemList*
list (2.S2CItemList.ListEntryRlistB
	ListEntry
key (Rkey
value (2	.ItemDataRvalue:8"2

C2SUseItem
id (Rid
count (Rcount".
S2CUpdateItem
list (2	.ItemDataRlist" 
C2SHello
hello (	Rhello" 
S2CWorld
world (	RworldBª
NetMessagebproto3