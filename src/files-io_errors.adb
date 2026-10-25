with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Hostkit.Host;

package body Files.Io_Errors is

   use type Hostkit.Host.Kind;

   --  Written by the thread that made the failing call and read by the one
   --  that chooses the message; a copy on a large-stack task hands it back
   --  through task completion, which already orders the two.
   Last : Integer := 0 with Atomic;

   function Host_Code (Item : Cause) return Integer is
      Host : constant Hostkit.Host.Kind := Hostkit.Host.Current;
   begin
      if Host = Hostkit.Host.Unsupported then
         return 0;
      end if;
      --  Every value below is from the host's own errno.h: Linux
      --  asm-generic/errno*.h, macOS sys/errno.h, Windows (UCRT and
      --  mingw-w64) errno.h. The first seven POSIX numbers agree everywhere.
      case Item is
         when No_Space =>
            return 28;
         when Quota_Exceeded =>
            case Host is
               when Hostkit.Host.Linux => return 122;
               when Hostkit.Host.MacOS => return 69;
               when others => return 0;
            end case;
         when Permission_Denied =>
            return 13;
         when Not_Permitted =>
            return 1;
         when Read_Only_Filesystem =>
            return 30;
         when Busy =>
            return 16;
         when Text_Busy =>
            return (if Host = Hostkit.Host.Windows then 139 else 26);
         when Name_Too_Long =>
            case Host is
               when Hostkit.Host.Linux => return 36;
               when Hostkit.Host.MacOS => return 63;
               when others => return 38;
            end case;
      end case;
   end Host_Code;

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
