with Ada.Strings.Unbounded;
with GNAT.OS_Lib;

package body Files.Io_Errors is

   use Hostkit.Errors;

   --  Written by the thread that made the failing call and read by the one
   --  that chooses the message; a copy on a large-stack task hands it back
   --  through task completion, which already orders the two.
   Last : Integer := 0 with Atomic;

   function Key_Of (Item : Cause) return String is
   begin
      case Item is
         when No_Space | Quota_Exceeded => return No_Space_Key;
         when Permission_Denied | Not_Permitted => return Denied_Key;
         when Read_Only_Filesystem => return Read_Only_Key;
         when Busy | Text_Busy => return Busy_Key;
         when Name_Too_Long => return Name_Too_Long_Key;
      end case;
   end Key_Of;

   function Key_For_Errno (Code : Integer; Fallback : String) return String is
   begin
      if Code /= 0 then
         for Item in Cause loop
            if Host_Code (Item) = Code then
               return Key_Of (Item);
            end if;
         end loop;
      end if;
      return Fallback;
   end Key_For_Errno;

   function Is_Cause_Key (Key : String) return Boolean is
     (Key = No_Space_Key or else Key = Denied_Key or else Key = Read_Only_Key
      or else Key = Busy_Key or else Key = Name_Too_Long_Key);

   function Is_Cause_Key (Key : Files.Types.UString) return Boolean is
     (Is_Cause_Key (Ada.Strings.Unbounded.To_String (Key)));

   procedure Reset is
   begin
      Last := 0;
      GNAT.OS_Lib.Set_Errno (0);
   end Reset;

   procedure Clear_Os_Error is
   begin
      GNAT.OS_Lib.Set_Errno (0);
   end Clear_Os_Error;

   procedure Capture is
   begin
      Record_Code (GNAT.OS_Lib.Errno);
   end Capture;

   procedure Record_Code (Code : Integer) is
   begin
      if Code /= 0 then
         Last := Code;
      end if;
   end Record_Code;

   function Last_Code return Integer is (Last);

   function Key_For_Last (Fallback : String) return String is
     (Key_For_Errno (Last, Fallback));

   function Error_Key (Fallback : String) return Files.Types.UString is
     (Ada.Strings.Unbounded.To_Unbounded_String (Key_For_Last (Fallback)));

end Files.Io_Errors;
