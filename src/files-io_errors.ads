with Files.Types;

--  Why an operating-system call failed, told as a catalog key.
--
--  A copy that ran out of space on a USB stick and one the user cancelled used
--  to report the same thing: that the copy failed. The call that failed knew
--  why -- errno said so -- but by the time a handler chose the message, cleanup
--  and further calls had overwritten it. A failing path records the code here
--  right after the call; the handler that picks the message asks for the key
--  of that cause, and keeps its own generic key when there is none.
--
--  One code is kept for the whole process: the last one recorded since the
--  operation began. An operation calls Reset when it starts, records with
--  Capture straight after each call it guards, and reads Error_Key before any
--  cleanup of its own can record something else.
package Files.Io_Errors is

   No_Space_Key      : constant String := "error.io.no_space";
   Denied_Key        : constant String := "error.io.denied";
   Read_Only_Key     : constant String := "error.io.read_only";
   Busy_Key          : constant String := "error.io.busy";
   Name_Too_Long_Key : constant String := "error.io.name_too_long";

   --  The causes told apart. Several share one key: a full disk and a full
   --  quota both mean there is no room, a refusal and a missing privilege both
   --  mean the user may not.
   type Cause is
     (No_Space,
      Quota_Exceeded,
      Permission_Denied,
      Not_Permitted,
      Read_Only_Filesystem,
      Busy,
      Text_Busy,
      Name_Too_Long);

   --  The errno value this host uses for a cause. They differ between hosts
   --  (ENAMETOOLONG is 36 on Linux, 63 on macOS, 38 on Windows), and GNAT's
   --  System.OS_Constants lacks most of them, so the values come from each
   --  host's errno.h.
   --  @param Item Cause to look up.
   --  @return The host's errno for Item, or zero when the host has none
   --    (EDQUOT on Windows) or Hostkit has no body for this host.
   function Host_Code (Item : Cause) return Integer;

   --  @param Item Cause to name.
   --  @return The catalog key a user is shown for Item.
   function Key_Of (Item : Cause) return String;

   --  @param Code An errno value from this host; zero means none.
   --  @param Fallback Key to answer when Code is no cause the user can act on.
   --  @return The key for Code's cause, or Fallback.
   function Key_For_Errno (Code : Integer; Fallback : String) return String;

   --  @param Key Catalog key to test.
   --  @return True when Key is one of the cause keys above.
   function Is_Cause_Key (Key : String) return Boolean;

   --  @param Key Catalog key to test.
   --  @return Is_Cause_Key for an unbounded key.
   function Is_Cause_Key (Key : Files.Types.UString) return Boolean;

   --  Forget the recorded code and clear errno, as an operation starts, so
   --  nothing an earlier operation left behind can explain this one.
   procedure Reset;

   --  Clear errno, and only errno, before a call that may fail without
   --  setting it (a Win32 or Cocoa API behind Hostkit, a check the runtime
   --  makes before its system call), so Capture then records nothing stale.
   procedure Clear_Os_Error;

   --  Record errno now. Call it straight after the call that failed, before
   --  anything else can overwrite errno. A zero errno records nothing.
   procedure Capture;

   --  Record Code as though errno had held it.
   --  @param Code An errno value; zero records nothing.
   procedure Record_Code (Code : Integer);

   --  @return The code recorded last since Reset, or zero.
   function Last_Code return Integer;

   --  @param Fallback Key to answer when nothing specific was recorded.
   --  @return Key_For_Errno (Last_Code, Fallback).
   function Key_For_Last (Fallback : String) return String;

   --  @param Fallback Key to answer when nothing specific was recorded.
   --  @return Key_For_Last (Fallback), ready for a Mutation_Result.
   function Error_Key (Fallback : String) return Files.Types.UString;

end Files.Io_Errors;
