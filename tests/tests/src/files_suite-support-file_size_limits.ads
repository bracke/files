with Ada.Finalization;
with System;
with Hostkit.Limits;

--  A stand-in for a full disk: the process's file-size limit, lowered so a
--  write past it fails (EFBIG) instead of filling a real disk. SIGXFSZ is
--  ignored while the limit is lowered, so the failing write returns an error
--  instead of ending the process. Hosts with no such limit (Windows) say so.
package Files_Suite.Support.File_Size_Limits is

   --  A lowered limit, put back by Lift (or when it goes out of scope).
   type Cap is limited private;

   --  Lower the limit to Bytes.
   --
   --  @param Item The cap to hold it.
   --  @param Bytes The largest size any file may be written to.
   --  @return False where the host has no file-size limit to lower.
   function Lower (Item : in out Cap; Bytes : Hostkit.Limits.Amount) return Boolean;

   --  Put the limit and SIGXFSZ back as they were; nothing when not lowered.
   --
   --  @param Item The cap.
   procedure Lift (Item : in out Cap);

private
   type Cap is new Ada.Finalization.Limited_Controlled with record
      Lowered    : Boolean := False;
      Old_Soft   : Hostkit.Limits.Amount := 0;
      Old_Signal : System.Address := System.Null_Address;
   end record;
   overriding procedure Finalize (Item : in out Cap);
end Files_Suite.Support.File_Size_Limits;
