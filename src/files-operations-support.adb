with Ada.Environment_Variables;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files.File_System;
with Files.Fs;

with Hostkit.Fs;

package body Files.Operations.Support is
   use Ada.Strings.Unbounded;
   use type GNAT.OS_Lib.String_Access;

   function Empty_Action return Files.Settings.Open_Action is
   begin
      return Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector);
   end Empty_Action;

   function Exists_Safely (Path : String) return Boolean is
   begin
      return Files.Fs.Exists (Path);
   exception
      when others =>
         return False;
   end Exists_Safely;

   function Make_Result
     (Status      : Operation_Status;
      Error_Key   : String := "";
      Path        : String := "";
      Action      : Files.Settings.Open_Action := Empty_Action;
      Attempted   : Boolean := False;
      Found       : Boolean := False;
      Exit_Known  : Boolean := False;
      Exit_Status : Integer := 0)
      return Operation_Result is
   begin
      return
        (Status    => Status,
         Error_Key => To_Unbounded_String (Error_Key),
         Path      => To_Unbounded_String (Path),
         Action    => Action,
         Action_Executable => Action.Executable,
         Action_Arguments  => Natural (Action.Arguments.Length),
         Action_Uses_Shell => Action.Use_Shell,
         Execution_Attempted => Attempted,
         Executable_Found    => Found,
         Exit_Status_Known   => Exit_Known,
         Exit_Status         => Exit_Status);
   end Make_Result;

   function Disabled
     (Model     : in out Files.Model.Window_Model;
      Error_Key : String)
      return Operation_Result is
   begin
      Files.Model.Set_Error (Model, Error_Key);
      return Make_Result (Operation_Disabled, Error_Key);
   end Disabled;

   function Safe_Environment_Value (Name : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;

      return "";
   exception
      when others =>
         return "";
   end Safe_Environment_Value;

   function Executable_Is_Available
     (Executable : String)
      return Boolean
   is
      Located : GNAT.OS_Lib.String_Access := null;
   begin
      if Executable = "" then
         return False;
      end if;

      for Character_Value of Executable loop
         if Character_Value = '/' or else Character_Value = '\' then
            --  A path, not a name to be looked up: it has to be a regular file that
            --  this host will actually run.
            --
            --  GNAT.OS_Lib.Is_Executable_File was the whole check, and on Windows it
            --  answers True for a directory -- so an action whose "executable" was a
            --  directory passed the preflight and got launched. It is the same shape
            --  as the lstat-less Is_Symbolic_Link: a POSIX-flavoured helper that
            --  quietly says yes there instead of failing.
            return Files.Fs.File_Exists (Executable)
              and then Hostkit.Fs.Is_Executable (Executable);
         end if;
      end loop;

      Located := GNAT.OS_Lib.Locate_Exec_On_Path (Executable);
      if Located = null then
         return False;
      end if;

      GNAT.OS_Lib.Free (Located);
      return True;
   exception
      when others =>
         if Located /= null then
            GNAT.OS_Lib.Free (Located);
         end if;
         return False;
   end Executable_Is_Available;

   function Reload_Current_Directory
     (Model       : in out Files.Model.Window_Model;
      Settings    : Files.Settings.Settings_Model;
      Select_Name : String := "")
      return Operation_Result
   is
      Load : constant Files.File_System.Directory_Load_Result :=
        Files.File_System.Load_Directory (Files.Model.Current_Path (Model), Settings);
   begin
      if not Load.Success then
         Files.Model.Set_Error (Model, To_String (Load.Error_Key));
         return Make_Result (Operation_Failed, To_String (Load.Error_Key), Files.Model.Current_Path (Model));
      end if;

      Files.Model.Replace_Items (Model, Load.Items);
      Files.Model.Set_Directory_Signature
        (Model,
         Files.File_System.Directory_State (Files.Model.Current_Path (Model)));
      if Select_Name /= "" then
         declare
            Selection_Restored : constant Boolean := Files.Model.Select_By_Name (Model, Select_Name);
            pragma Unreferenced (Selection_Restored);
         begin
            null;
         end;
      end if;
      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
   end Reload_Current_Directory;

end Files.Operations.Support;
