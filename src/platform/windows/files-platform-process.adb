with Ada.Strings.UTF_Encoding.Wide_Strings;

with Interfaces.C;

with System;

package body Files.Platform.Process is

   use type Interfaces.C.int;
   use type Interfaces.C.unsigned_long;

   subtype C_DWord is Interfaces.C.unsigned_long;

   Infinite     : constant C_DWord := 16#FFFF_FFFF#;
   Still_Active : constant C_DWord := 259;
   Wait_Failed  : constant C_DWord := 16#FFFF_FFFF#;

   type Startup_Info is record
      Cb              : C_DWord := 0;
      Reserved        : System.Address := System.Null_Address;
      Desktop         : System.Address := System.Null_Address;
      Title           : System.Address := System.Null_Address;
      X               : C_DWord := 0;
      Y               : C_DWord := 0;
      X_Size          : C_DWord := 0;
      Y_Size          : C_DWord := 0;
      X_Count_Chars   : C_DWord := 0;
      Y_Count_Chars   : C_DWord := 0;
      Fill_Attribute  : C_DWord := 0;
      Flags           : C_DWord := 0;
      Show_Window     : Interfaces.C.unsigned_short := 0;
      Reserved2_Count : Interfaces.C.unsigned_short := 0;
      Reserved2       : System.Address := System.Null_Address;
      Std_Input       : System.Address := System.Null_Address;
      Std_Output      : System.Address := System.Null_Address;
      Std_Error       : System.Address := System.Null_Address;
   end record
     with Convention => C;

   type Process_Information is record
      Process    : System.Address := System.Null_Address;
      Thread     : System.Address := System.Null_Address;
      Process_Id : C_DWord := 0;
      Thread_Id  : C_DWord := 0;
   end record
     with Convention => C;

   --  These layouts are a contract with the OS, not a description of our own record,
   --  so pin them: a field silently mis-sized here is a corrupt call rather than a
   --  compile error. 104 and 24 are the x86-64 layouts.
   pragma Compile_Time_Error
     (Startup_Info'Size /= 104 * 8, "STARTUPINFOW layout does not match the Win32 one");
   pragma Compile_Time_Error
     (Process_Information'Size /= 24 * 8, "PROCESS_INFORMATION layout does not match the Win32 one");

   function Create_Process
     (Application_Name   : System.Address;
      Command_Line       : System.Address;
      Process_Attributes : System.Address;
      Thread_Attributes  : System.Address;
      Inherit_Handles    : Interfaces.C.int;
      Creation_Flags     : C_DWord;
      Environment        : System.Address;
      Current_Directory  : System.Address;
      Startup            : access Startup_Info;
      Information        : access Process_Information)
      return Interfaces.C.int
     with Import => True, Convention => Stdcall, External_Name => "CreateProcessW";

   function Wait_For_Single_Object
     (Handle       : System.Address;
      Milliseconds : C_DWord)
      return C_DWord
     with Import => True, Convention => Stdcall, External_Name => "WaitForSingleObject";

   function Get_Exit_Code_Process
     (Process   : System.Address;
      Exit_Code : access C_DWord)
      return Interfaces.C.int
     with Import => True, Convention => Stdcall, External_Name => "GetExitCodeProcess";

   function Close_Handle (Handle : System.Address) return Interfaces.C.int
     with Import => True, Convention => Stdcall, External_Name => "CloseHandle";

   --  Windows has no zombie: a process that has exited is gone once its handles are
   --  closed, and Run_Command_Line closes both before returning. Nothing to collect.
   procedure Reap_Finished_Children is
   begin
      null;
   end Reap_Finished_Children;

   function Supports_Raw_Command_Line return Boolean is
   begin
      return True;
   end Supports_Raw_Command_Line;

   function Run_Command_Line
     (Command     : String;
      Wait        : Boolean;
      Exit_Status : out Integer)
      return Boolean
   is
      --  CreateProcessW is documented to be able to write to this buffer, so it has
      --  to be our own mutable copy.
      Wide_Command : aliased Wide_String :=
        Ada.Strings.UTF_Encoding.Wide_Strings.Decode (Command) & Wide_Character'Val (0);

      Startup     : aliased Startup_Info;
      Information : aliased Process_Information;
      Exit_Code   : aliased C_DWord := 0;
      Waited      : C_DWord;
      Created     : Interfaces.C.int;
      Ignored     : Interfaces.C.int;
   begin
      Exit_Status := -1;
      Startup.Cb := C_DWord (Startup_Info'Size / 8);

      Created :=
        Create_Process
          (Application_Name   => System.Null_Address,
           Command_Line       => Wide_Command'Address,
           Process_Attributes => System.Null_Address,
           Thread_Attributes  => System.Null_Address,
           Inherit_Handles    => 0,
           Creation_Flags     => 0,
           Environment        => System.Null_Address,
           Current_Directory  => System.Null_Address,
           Startup            => Startup'Access,
           Information        => Information'Access);

      if Created = 0 then
         return False;
      end if;

      if not Wait then
         --  Closing our handles does not end the process; it only says we are not
         --  watching it, which is exactly what a detached launch means.
         Ignored := Close_Handle (Information.Thread);
         Ignored := Close_Handle (Information.Process);
         return True;
      end if;

      Waited := Wait_For_Single_Object (Information.Process, Infinite);

      if Waited /= Wait_Failed
        and then Get_Exit_Code_Process (Information.Process, Exit_Code'Access) /= 0
        and then Exit_Code /= Still_Active
      then
         Exit_Status := Integer (Exit_Code);
      end if;

      Ignored := Close_Handle (Information.Thread);
      Ignored := Close_Handle (Information.Process);

      return Exit_Status /= -1;
   exception
      when others =>
         return False;
   end Run_Command_Line;

end Files.Platform.Process;
