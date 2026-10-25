with Ada.Environment_Variables;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files.File_System;
with Files.Refresh_Jobs;
with Files.Fs_Primitives;

with Hostkit.Fs;
with Hostkit.Host;

package body Files.Operations.Support is
   use Ada.Strings.Unbounded;
   use type GNAT.OS_Lib.String_Access;

   function Empty_Action return Files.Settings.Open_Action is
   begin
      return Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector);
   end Empty_Action;

   function Exists_Safely (Path : String) return Boolean is
   begin
      return Files.Fs_Primitives.Exists (Path) or else Hostkit.Fs.Is_Link (Path);
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
     (Ada.Environment_Variables.Value (Name, ""));

   function Executable_Is_Available
     (Executable : String)
      return Boolean
   is
      use type Hostkit.Host.Kind;
      Located : GNAT.OS_Lib.String_Access := null;
   begin
      if Executable = "" then
         return False;
      end if;

      for Character_Value of Executable loop
         if Character_Value = '/'
           or else
             (Hostkit.Host.Current = Hostkit.Host.Windows
              and then Character_Value = '\')
         then
            --  A path, not a name to be looked up: it has to be a regular file that
            --  this host will actually run.
            --
            --  GNAT.OS_Lib.Is_Executable_File was the whole check, and on Windows it
            --  answers True for a directory -- so an action whose "executable" was a
            --  directory passed the preflight and got launched. It is the same shape
            --  as the lstat-less Is_Symbolic_Link: a POSIX-flavoured helper that
            --  quietly says yes there instead of failing.
            return Files.Fs_Primitives.File_Exists (Executable)
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
      Select_Name : String := "";
      Preserve_Selection : Boolean := False)
      return Operation_Result
   is
      Previous_Selection : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Previous_Primary : constant String :=
        To_String (Files.Model.Selected_Item (Model).Full_Path);
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Refresh_Jobs.Start (Model, Settings, Force => True, Select_Name => Select_Name);
      end if;
      --  The Recent view has no backing directory (Current_Path is empty), so a
      --  directory load would spuriously fail and a mutation performed from
      --  Recent would be reported as failed with the view left stale. Rebuild it
      --  from the recorded recent paths instead, dropping any that no longer
      --  resolve. Mirrors Navigation.Navigate_Recent, which this lower-level
      --  shared helper cannot call.
      if Files.Model.In_Recent_View (Model) then
         declare
            Recent : constant Files.Types.String_Vectors.Vector :=
              Files.Settings.Recent_Paths (Settings);
            Items  : Files.File_System.Item_Vectors.Vector;
         begin
            for Path of Recent loop
               declare
                  Loaded : constant Files.File_System.Item_Load_Result :=
                    Files.File_System.Load_Item (To_String (Path), Settings);
               begin
                  if Loaded.Success then
                     Items.Append (Loaded.Item);
                  end if;
               end;
            end loop;
            Files.Model.Navigate_Recent (Model, Items);
            if Preserve_Selection and then Select_Name = "" then
               Files.Model.Restore_Selection
                 (Model, Previous_Selection, Previous_Primary);
            end if;
            Files.Model.Set_Error (Model, "");
         end;
         return Make_Result (Operation_Success);
      end if;

      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory_Deferring_Thumbnails (Files.Model.Current_Path (Model), Settings);
      begin
         if not Load.Success then
            Files.Model.Set_Error (Model, To_String (Load.Error_Key));
            return
              Make_Result (Operation_Failed, To_String (Load.Error_Key), Files.Model.Current_Path (Model));
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
         elsif Preserve_Selection then
            Files.Model.Restore_Selection
              (Model, Previous_Selection, Previous_Primary);
         end if;
         Files.Model.Set_Error (Model, "");
         Files.Operations.Ensure_Selected_Item_Extra (Model);
         --  A reload runs after every operation, so it must not decode each
         --  new image in the folder while the UI waits: as on navigation, the
         --  missing thumbnails are left to a background listing, which the
         --  window's next poll launches.
         if Files.File_System.Thumbnails_Missing (Load.Items) then
            Files.Model.Note_Owed_Refresh (Model, Force => True, Select_Name => "");
         end if;
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end;
   end Reload_Current_Directory;

   function Reload_With_Error
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Error_Key : String) return Operation_Result
   is
      Reload : Operation_Result;
   begin
      Files.Model.Set_Error (Model, Error_Key);
      Reload := Reload_Current_Directory (Model, Settings);
      if not Files.Model.Background_Transfers (Model) then
         Files.Model.Set_Error (Model, Error_Key);
      end if;
      return Reload;
   end Reload_With_Error;

   procedure Generate_Missing_Thumbnails
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Items    : Files.File_System.Item_Vectors.Vector) is
   begin
      if Files.File_System.Thumbnails_Missing (Items) then
         declare
            Started : constant Operation_Result := Files.Refresh_Jobs.Start (Model, Settings, Force => True);
            pragma Unreferenced (Started);
         begin
            null;
         end;
      end if;
   end Generate_Missing_Thumbnails;

end Files.Operations.Support;
