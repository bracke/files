with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Types;

with Files.Operations.Support;

separate (Files.Operations)
package body Navigation is
   use type Files.File_System.Path_Status;
   use type Files.Types.Item_Kind;

   procedure Apply_Ui_State
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      Mapped : constant Files.Model.Sort_Field :=
        (case Settings.Sort_Field_Value is
            when Files.Settings.Sort_By_Name     => Files.Model.Sort_Name,
            when Files.Settings.Sort_By_Filetype => Files.Model.Sort_Type,
            when Files.Settings.Sort_By_Size     => Files.Model.Sort_Size,
            when Files.Settings.Sort_By_Created  => Files.Model.Sort_Created,
            when Files.Settings.Sort_By_Modified => Files.Model.Sort_Changed);
   begin
      Files.Model.Set_View_Mode (Model, Settings.Default_View);
      Files.Model.Apply_Sort (Model, Mapped, Settings.Sort_Ascending);
   end Apply_Ui_State;

   function Refresh
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      --  The virtual recent view has no backing directory to reload; rebuild its
      --  synthetic listing from the current recent paths instead.
      if Files.Model.In_Recent_View (Model) then
         return Navigate_Recent (Model, Settings);
      end if;
      --  Preserve the current selection across a manual refresh when the item
      --  still exists (Reload re-selects by name; empty name => no selection).
      return Reload_Current_Directory (Model, Settings, Files.Model.Selected_Name (Model));
   end Refresh;

   function Refresh_If_Changed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Change : constant Files.File_System.Directory_Change_Result :=
        Files.File_System.Detect_Directory_Change
          (Files.Model.Directory_Signature_Of (Model),
           Files.Model.Current_Path (Model));
   begin
      if Length (Change.Error_Key) > 0 then
         Files.Model.Set_Error (Model, To_String (Change.Error_Key));
         return Make_Result (Operation_Failed, To_String (Change.Error_Key), Files.Model.Current_Path (Model));
      elsif not Change.Changed then
         Files.Model.Set_Directory_Signature (Model, Change.After_State);
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end if;

      --  Preserve the selection across an auto-refresh triggered by a
      --  background directory change, when the item still exists.
      return Reload_Current_Directory (Model, Settings, Files.Model.Selected_Name (Model));
   end Refresh_If_Changed;

   function Commit_Path_Input
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Path_Result : constant Files.File_System.Path_Result :=
        Files.File_System.Normalize_Path (Files.Model.Path_Input_Text (Model));
      Empty_Items : Files.File_System.Item_Vectors.Vector;
   begin
      if Path_Result.Status /= Files.File_System.Path_Valid then
         Files.Model.Commit_Path_Input (Model, Path_Result, Empty_Items);
         Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
         return Make_Result (Operation_Failed, To_String (Path_Result.Error_Key));
      end if;

      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (To_String (Path_Result.Directory_Path), Settings);
      begin
         if not Load.Success then
            Files.Model.Set_Error (Model, To_String (Load.Error_Key));
            return Make_Result (Operation_Failed, To_String (Load.Error_Key), To_String (Path_Result.Directory_Path));
         end if;

         Files.Model.Commit_Path_Input (Model, Path_Result, Load.Items);
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (To_String (Path_Result.Directory_Path)));
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Navigated, Path => To_String (Path_Result.Directory_Path));
      end;
   end Commit_Path_Input;

   --  Shared normalize -> load -> navigate tail for the absolute-destination
   --  navigations (Home, Parent, Trash, Select_Root). Path is the raw requested
   --  path; on a normalize failure the error is reported against it, on a load
   --  failure against the normalized path. Close_Selector closes the root selector
   --  after a successful navigation (used only by Select_Root).
   function Load_And_Navigate
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Path           : String;
      Close_Selector : Boolean := False)
      return Operation_Result
   is
      Path_Result : constant Files.File_System.Path_Result :=
        Files.File_System.Normalize_Path (Path);
   begin
      if Path_Result.Status /= Files.File_System.Path_Valid then
         Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
         return Make_Result
           (Operation_Failed, To_String (Path_Result.Error_Key), Path);
      end if;

      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (To_String (Path_Result.Directory_Path), Settings);
      begin
         if not Load.Success then
            Files.Model.Set_Error (Model, To_String (Load.Error_Key));
            return Make_Result
              (Operation_Failed,
               To_String (Load.Error_Key),
               To_String (Path_Result.Directory_Path));
         end if;

         Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (To_String (Load.Path)));
         if Close_Selector then
            Files.Model.Close_Root_Selector (Model);
         end if;
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
      end;
   end Load_And_Navigate;

   type History_Direction is (History_Back, History_Forward);

   --  History navigation shared by Navigate_Back and Navigate_Forward: mirror
   --  images differing only in the availability check, the error key, the move,
   --  and which way the rollback moves on a failed reload.
   function Navigate_History
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Direction : History_Direction)
      return Operation_Result
   is
      Had_Temporary  : constant Boolean := Files.Model.Temporary_Item_Is_Active (Model);
      Temporary_Name : constant String := Files.Model.Temporary_Item_Name (Model);
      Had_Rename     : constant Boolean := Files.Model.Rename_Is_Active (Model);
      Rename_Text    : constant String := Files.Model.Rename_Text (Model);
      Rename_Source  : constant String := Files.Model.Selected_Name (Model);
      Available      : constant Boolean :=
        (if Direction = History_Back
         then Files.Model.Can_Go_Back (Model)
         else Files.Model.Can_Go_Forward (Model));
      Error_Key      : constant String :=
        (if Direction = History_Back
         then "error.history.back_unavailable"
         else "error.history.forward_unavailable");
   begin
      if not Available then
         return Disabled (Model, Error_Key);
      end if;

      if Direction = History_Back then
         Files.Model.Go_Back (Model);
      else
         Files.Model.Go_Forward (Model);
      end if;

      declare
         Reload : constant Operation_Result := Refresh (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            --  Undo the history move, then restore any interrupted rename/create.
            if Direction = History_Back then
               Files.Model.Go_Forward (Model);
            else
               Files.Model.Go_Back (Model);
            end if;
            if Had_Temporary then
               Files.Model.Begin_Create_File (Model, Temporary_Name);
            elsif Had_Rename then
               declare
                  Selection_Restored : constant Boolean :=
                    Files.Model.Select_By_Name (Model, Rename_Source);
                  pragma Unreferenced (Selection_Restored);
               begin
                  null;
               end;
               Files.Model.Resume_Rename (Model, Rename_Text);
            end if;
         end if;

         return Reload;
      end;
   end Navigate_History;

   function Navigate_Home
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Load_And_Navigate (Model, Settings, Files.Model.Home_Path (Model));
   end Navigate_Home;

   function Navigate_Parent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Parent : constant String :=
        Files.File_System.Parent_Directory (Files.Model.Current_Path (Model));
   begin
      --  A filesystem root has no parent, so navigating up is a safe no-op.
      if Parent = "" then
         return Disabled (Model, "error.navigate.no_parent");
      end if;

      return Load_And_Navigate (Model, Settings, Parent);
   end Navigate_Parent;

   function Navigate_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Trash_Dir : constant String := Files.File_System.Trash_Files_Directory;
   begin
      if Trash_Dir = "" then
         Files.Model.Set_Error (Model, "error.trash.unavailable");
         return Make_Result (Operation_Failed, "error.trash.unavailable", Trash_Dir);
      end if;

      return Load_And_Navigate (Model, Settings, Trash_Dir);
   end Navigate_Trash;

   function Navigate_Recent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Recent : constant Files.Types.String_Vectors.Vector :=
        Files.Settings.Recent_Paths (Settings);
      Items  : Files.File_System.Item_Vectors.Vector;
   begin
      --  Stat each stored path in most-recent-first order, skipping any that no
      --  longer resolve so a stale entry silently drops from the view.
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
      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Navigated);
   end Navigate_Recent;

   function Navigate_Back
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Navigate_History (Model, Settings, History_Back);
   end Navigate_Back;

   function Navigate_Forward
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Navigate_History (Model, Settings, History_Forward);
   end Navigate_Forward;

   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Operation_Result is
   begin
      return Load_And_Navigate (Model, Settings, Root_Path, Close_Selector => True);
   end Select_Root;

   function Eject_Selected_Root
     (Model : in out Files.Model.Window_Model)
      return Operation_Result
   is
      Index : constant Natural := Files.Model.Root_Selected_Index (Model);
      Path  : Unbounded_String;
   begin
      if not Files.Model.Root_Selector_Is_Open (Model)
        or else Index = 0
        or else Index > Files.Model.Root_Count (Model)
      then
         return Disabled (Model, "error.root.selection.empty");
      end if;

      Path := To_Unbounded_String (Files.Model.Root_Path (Model, Index));
      if not Files.Model.Root_Is_Removable (Model, Index) then
         return Disabled (Model, "error.root.eject_unavailable");
      end if;

      Files.Model.Set_Error (Model, "error.root.eject_unavailable");
      return Make_Result
        (Operation_Failed,
         "error.root.eject_unavailable",
         To_String (Path));
   end Eject_Selected_Root;

end Navigation;
