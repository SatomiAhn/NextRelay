//Flexi Relay, by Satomi Ahn
//
//This script is provided as-is with mo guarrantee whatsoever.
//Feel free to use the code under the terms of OpenCollar License 
//(GPLv2 + obligation of keeping scripts full perm in all virtual worlds they are distributed).

integer rlvrc = -1812221819;
key source = NULL_KEY;
key wearer = NULL_KEY;
integer listener;
key sitid;
list restrictions = [];
integer nbprims;
integer press_time;

release(key id) {
    integer count = 0;
    integer i; for (i = 2; i <= nbprims; i++)
    {
        string ldesc = llList2String(llGetLinkPrimitiveParams(i, [PRIM_DESC]), 0);
        if ("idle" == ldesc) count++;
    }
//    llOwnerSay("found "+(string)count+" idle relays.");
    if (count)
    {
        llSetAlpha(0.0, ALL_SIDES);
        llSetPrimitiveParams([PRIM_DESC, ""]);
        llMessageLinked(LINK_ROOT, FALSE, "", source);
        llRemoveInventory(llGetScriptName());
    }
    else llResetScript();
}

default {
    state_entry() {
        llMessageLinked(LINK_ROOT, TRUE, "", NULL_KEY);
        nbprims = llGetNumberOfPrims();
        llSetAlpha(0.5, ALL_SIDES);
        llSetPrimitiveParams([PRIM_DESC, "idle"]);
        llSetMemoryLimit(24000);
        wearer = llGetOwner();
        listener = llListen(rlvrc,"", NULL_KEY, "");
//        llOwnerSay("Relay ready and listening in link number "+(string)llGetLinkNumber());
    }

    touch_start(integer total_number) {
        if (source) {
            llOwnerSay("This relay is locked by "+llKey2Name(source)+" ("+(string)source+"), with behaviors: " + llDumpList2String(restrictions, ", ") + ".\nKeep your mouse button pressed for 3 seconds if you want to safeword this source.");
            llOwnerSay("Memory: "+(string)llGetUsedMemory());
            press_time = llGetUnixTime();
        }
        else {
            llOwnerSay("This relay is ready to accept a new source.");
        }
    }
    
    touch(integer tot)
    {
        if (press_time && llGetUnixTime() - press_time > 3)
        {
            if (source)
            {
                llOwnerSay("@clear");
                llRegionSayTo(source, rlvrc, "release,"+(string)source+",!release,ok");
                llSetAlpha(0.2, ALL_SIDES);
                llSleep(5.);
                press_time = FALSE;
                release(source);
            }
        }
    }
    
    listen(integer c, string w, key id, string msg) {
        if (source == NULL_KEY) {
            integer i;
            if (!llList2Integer(llGetLinkPrimitiveParams(1, [PRIM_DESC]), 0)) return;
            for (i=2; i <= nbprims; i++)
            if (llList2Key(llGetLinkPrimitiveParams(i, [PRIM_DESC]), 0) == id)
            return; // ignore source if already handled in another primitive
        }
        else if (source != id) return; // sanity check, should not even be needed
        else llListenRemove(listener); // delayed old listener removal (doing it too soon will lose messages already in event queue)
        list args = llParseStringKeepNulls(msg,[","],[]);
        if (llGetListLength(args)!=3) return;
        if (llList2Key(args,1)!=wearer && llList2Key(args, 1)!=(key)"ffffffff-ffff-ffff-ffff-ffffffffffff") return;
        string ident = llList2String(args,0);
        list commands = llParseString2List(llList2String(args,2),["|"],[]);
        integer i;
        string command;
        integer nc = llGetListLength(commands);
        for (i=0; i<nc; ++i) {
            command = llList2String(commands,i);
            if (llGetSubString(command,0,0)=="@") {
                llOwnerSay(command);
                llRegionSayTo(id, rlvrc, ident+","+(string)id+","+command+",ok");
                list subargs = llParseString2List(command, ["="], []);
                string behav = llGetSubString(llList2String(subargs, 0), 1, -1);
                integer index = llListFindList(restrictions, [behav]);
                string comtype = llList2String(subargs, 1);                
                if (comtype == "n" || comtype == "add") {
                    if (index == -1 && behav!= "edit") restrictions += [behav];
                    if (behav == "unsit" && llGetAgentInfo(wearer) & AGENT_SITTING) {
                        sitid = llList2Key(llGetObjectDetails(wearer, [OBJECT_ROOT]), 0);
                    }
                }
                else if (comtype=="y" || comtype == "rem") {
                    if (index != -1) restrictions = llDeleteSubList(restrictions, index, index);
                    if (behav == "unsit") sitid = NULL_KEY;
                }
            }
            else if (command=="!pong") {
                    llOwnerSay("@sit:"+(string)sitid+"=force,"+llDumpList2String(restrictions, "=n,")+"=n");
                    llSetTimerEvent(0);
            }
            else if (command=="!version") llRegionSayTo(id, rlvrc, ident+","+(string)id+",!version,1100");
            else if (command=="!implversion") llRegionSayTo(id, rlvrc, ident+","+(string)id+",!implversion,ORG=0003/Satomi's Flexi Relay");
            else if (command=="!x-orgversions") llRegionSayTo(id, rlvrc, ident+","+(string)id+",!x-orgversions,ORG=0003");
            else if (command=="!release") restrictions = [];
            else llRegionSayTo(id, rlvrc, ident+","+(string)id+","+command+",ko");            
        }
        if (NULL_KEY == source && [] != restrictions) {
            source = id;
            llListen(rlvrc,"", source, "");
            llMessageLinked(LINK_ROOT, TRUE, "", source);
            llOwnerSay("@detach=n");
            llSetAlpha(1.0, ALL_SIDES);
            llSetPrimitiveParams([PRIM_DESC, (string)id]);
            integer i; for (i = 2; i <= nbprims; i++)
            {
                string ldesc = llList2String(llGetLinkPrimitiveParams(i, [PRIM_DESC]), 0);
                key lkey = llGetLinkKey(i);
//                llOwnerSay("prim #"+(string) i+": " + ldesc);
                if ("" == ldesc)
                {//llOwnerSay("trying prim #"+(string)i);
                    llRemoteLoadScriptPin(lkey, llGetScriptName(), 1234, TRUE, 0);
                    return;
                }
            }
            llOwnerSay("All prims now contain a locked relay. From now on, and until a relay is released, only already known sources will be relayed.");
        }
        else if (NULL_KEY != source && [] == restrictions) { llOwnerSay("@clear");
 release(source);}
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) llResetScript();
    }
    
    on_rez(integer i) {
        if (source) {
            llSleep(30);
            llRegionSayTo(source, rlvrc, "ping,"+(string)source+",ping,ping");
            llSetTimerEvent(30);
        }
    }
    
    timer() {
        release(source);
    }
}
