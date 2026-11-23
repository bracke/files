with Files.Model.Jobs;
with Files.File_System.Trash;
with Files.Model.Recent;
with Files.Command_Reasons;
with Files.Jobs.Context;
with Ada.Directories;
with Files.Diagnostics;

with Files.File_System;
with Files.File_System.Transfer;
with Files.Refresh;
with Files.IO.Fs_Primitives;
with Files.Leaf_Names;
with Hostkit.Fs;
with Files.Model.Selection;
with Files.Model.Filtering;
with Files.File_System.Search;
with Files.File_Types;
with Files.Settings.Open_Actions;

package body Files.Operations.Support is
   use Ada.Strings.Unbounded;

   function First_Free_Leaf
     (Directory : String;
      Base      : String;
      Extension : String;
      Marker    : not null access function (Attempt : Natural) return String;
      First     : Natural := 1)
      return String
   is
      --  Asked once: the search may try thousands of names.
      Limit : constant Hostkit.Fs.Leaf_Name_Limit := Hostkit.Fs.Leaf_Name_Limit_At (Directory);

      --  A name the host will not answer for raises (Is_Taken): never
      --  handed out as free.
      function Taken (Leaf : String) return Boolean is
        (Files.IO.Fs_Primitives.Is_Taken (Hostkit.Fs.Join (Directory, Leaf)));

      Free : constant String :=
        Files.Leaf_Names.First_Free (Base, Extension, Marker, Taken'Access, Limit, First);
   begin
      if Free = "" then
         raise Ada.Directories.Use_Error with "no_free_name=" & Directory;
      end if;
      return Free;
   end First_Free_Leaf;

   function Empty_Action return Files.Settings.Open_Action is
   begin
      return Files.Settings.Open_Actions.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector);
   end Empty_Action;

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
         Execution =>
           (Attempted         => Attempted,
            Executable_Found  => Found,
            Exit_Status_Known => Exit_Known,
            Exit_Status       => Exit_Status));
   end Make_Result;

   function Disabled
     (Model     : in out Files.Model.Window_Model;
      Error_Key : String)
      return Operation_Result is
   begin
      Files.Model.Set_Error (Model, Error_Key);
      return Make_Result (Operation_Disabled, Error_Key);
   end Disabled;

   function Real_Selection_Refusal (Model : in out Files.Model.Window_Model) return Operation_Result is
      package Reasons renames Files.Command_Reasons;
   begin
      if Files.Model.Selection.Selected_Count (Model) = 0 then
         return Disabled (Model, Reasons.Reason_Key (Reasons.Selection_Empty_Reason));
      elsif Files.Model.Selection.Includes_Temporary (Model) then
         return Disabled (Model, Reasons.Reason_Key (Reasons.Create_Pending_Reason));
      end if;
      return (Status => Operation_Success, others => <>);
   end Real_Selection_Refusal;

   function Reloads_In_Background (Model : Files.Model.Window_Model) return Boolean is
     (Files.Model.Jobs.Background_Transfers (Model)
      and then not Files.Model.Filtering.Search_Results_Are_Active (Model));

   function Reload_Current_Directory
     (Model       : in out Files.Model.Window_Model;
      Settings    : Files.Settings.Settings_Model;
      Select_Name : String := "";
      Preserve_Selection : Boolean := False;
      Select_Path : String := "")
      return Operation_Result
   is
   begin
      if Reloads_In_Background (Model) then
         return Files.Refresh.Start (Model, Settings, Force => True, Select_Name => Select_Name);
      end if;
      Reload_In_Place :
      declare
         --  Only a reload here restores them: the background one above
         --  restores its own, so a Select All is not copied for nothing.
         Previous_Selection : constant Files.Types.String_Vectors.Vector :=
           Files.Model.Selection.Selected_Paths (Model);
         Previous_Primary : constant String :=
           To_String (Files.Model.Selection.Selected_Item (Model).Full_Path);
      begin
         --  The Recent view has no backing directory (Current_Path is empty), so a
         --  directory load would spuriously fail and a mutation performed from
         --  Recent would be reported as failed with the view left stale. Rebuild it
         --  from the recorded recent paths instead (Load_Recent_Items).
         if Files.Model.Recent.In_Recent_View (Model) then
            Files.Model.Navigate_Recent (Model, Files.Refresh.Load_Recent_Items (Settings));
            if Preserve_Selection and then Select_Name = "" then
               Files.Model.Selection.Restore
                 (Model, Previous_Selection, Previous_Primary);
            end if;
            Files.Model.Set_Error (Model, "");
            return Make_Result (Operation_Success);
         end if;

         --  Search results have no folder listing to reload: the search runs
         --  again, so what the operation changed shows among them and they
         --  stay shown (a folder listing put in their place left the view
         --  saying it held results).
         if Files.Model.Filtering.Search_Results_Are_Active (Model) then
            declare
               Searched : constant Operation_Result :=
                 Search_Current_Folder
                   (Model, Settings,
                    Files.UI_Types.Tree_Search_Scope (Files.Model.Filtering.Search_Scope_Of (Model)));
            begin
               if Searched.Status = Operation_Success then
                  if Select_Path /= "" then
                     Files.Model.Selection.Restore
                       (Model, Files.Types.String_Vectors.To_Vector (To_Unbounded_String (Select_Path), 1),
                        Select_Path);
                  else
                     Files.Model.Selection.Restore (Model, Previous_Selection, Previous_Primary);
                  end if;
               end if;
               return Searched;
            end;
         end if;

         declare
            Load : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory_Deferring_Thumbnails
                (Files.Model.Current_Path (Model), Files.Settings.Classification_Of (Settings),
                 Files.Settings.Listing_Options_Of (Settings));
         begin
            if not Load.Success then
               Files.Model.Set_Error (Model, To_String (Load.Error_Key));
               return
                 Make_Result (Operation_Failed, To_String (Load.Error_Key), Files.Model.Current_Path (Model));
            end if;

            Files.Model.Replace_Items (Model, Load.Items);
            Files.Model.Set_Directory_Signature (Model, Load.Signature);
            if Select_Path /= "" then
               Files.Model.Selection.Restore
                 (Model, Files.Types.String_Vectors.To_Vector (To_Unbounded_String (Select_Path), 1), Select_Path);
            elsif Select_Name /= "" then
               declare
                  Selection_Restored : constant Boolean := Files.Model.Selection.Select_By_Name (Model, Select_Name);
                  pragma Unreferenced (Selection_Restored);
               begin
                  null;
               end;
            elsif Preserve_Selection then
               Files.Model.Selection.Restore
                 (Model, Previous_Selection, Previous_Primary);
            end if;
            Files.Model.Set_Error (Model, "");
            Files.Refresh.Ensure_Selected_Item_Extra (Model, Settings.Show_Hidden_Files);
            --  A reload runs after every operation, so it must not decode each
            --  new image in the folder while the UI waits: as on navigation, the
            --  missing thumbnails are left to a background listing, which the
            --  window's next poll launches.
            if Files.File_System.Thumbnails_Missing (Load.Items) then
               Files.Model.Note_Owed_Refresh (Model, Force => True, Select_Name => "");
            end if;
            return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
         end;
      end Reload_In_Place;
   end Reload_Current_Directory;

   function Search_Current_Folder
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Scope    : Files.UI_Types.Tree_Search_Scope)
      return Operation_Result
   is
      use type Files.UI_Types.Search_Scope;
      Query   : constant String := Files.Model.Filtering.Filter_Text (Model);
      Root    : constant String := Files.Model.Current_Path (Model);
      Classes : constant Files.File_Types.Classification := Files.Settings.Classification_Of (Settings);
      Options : constant Files.Types.Listing_Options := Files.Settings.Listing_Options_Of (Settings);
      Found   : constant Files.File_System.Search.Recursive_Search_Result :=
        (if Scope = Files.UI_Types.Search_Contents
         then Files.File_System.Search.Search_Contents (Root, Query, Classes, Options)
         else Files.File_System.Search.Search_Names (Root, Query, Classes, Options));
   begin
      if not Found.Success then
         Files.Model.Set_Error (Model, To_String (Found.Error_Key));
         return Make_Result (Operation_Failed, To_String (Found.Error_Key), Root);
      end if;
      Files.Model.Replace_Items (Model, Found.Items);
      Files.Model.Filtering.Note_Search_Results (Model, Scope);
      Files.Model.Set_Directory_Signature (Model, Files.File_System.Directory_State (Root));
      --  A partial answer is still shown, with a notice that it is one: a
      --  limit cut it short, or something under the root went unsearched.
      Files.Model.Set_Error
        (Model,
         (if Found.Truncated then "search.truncated"
          elsif Found.Incomplete then "search.incomplete"
          elsif Found.Items.Is_Empty then "search.no_matches"
          else ""));
      return Make_Result (Operation_Success, Path => Root);
   end Search_Current_Folder;

   function Batch_Failed
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Error_Key  : String;
      Directory  : String;
      Wrote_Some : Boolean)
      return Operation_Result is
   begin
      if Wrote_Some then
         Reload_With_Error (Model, Settings, Error_Key);
      else
         Files.Model.Set_Error (Model, Error_Key);
      end if;
      return Make_Result (Operation_Failed, Error_Key, Directory);
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.Operations.Support");
         Files.Model.Set_Error (Model, Error_Key);
         return Make_Result (Operation_Failed, Error_Key, Directory);
   end Batch_Failed;

   procedure Reload_With_Error
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Error_Key : String;
      Path : String := "")
   is
      Reload : Operation_Result;
      pragma Unreferenced (Reload);
   begin
      --  Set before the reload is scheduled (a background one keeps it) and
      --  again after one done here, which clears the error it finds.
      Files.Model.Set_Error (Model, Error_Key, Path);
      Reload := Reload_Current_Directory (Model, Settings);
      if not Reloads_In_Background (Model) then
         Files.Model.Set_Error (Model, Error_Key, Path);
      end if;
   end Reload_With_Error;

   procedure Generate_Missing_Thumbnails
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Items    : Files.Items.Item_Vectors.Vector) is
   begin
      if Files.File_System.Thumbnails_Missing (Items) then
         declare
            Started : constant Operation_Result := Files.Refresh.Start (Model, Settings, Force => True);
            pragma Unreferenced (Started);
         begin
            null;
         end;
      end if;
   end Generate_Missing_Thumbnails;

   function Publish_Staged
     (Staged   : String;
      Target   : String;
      Identity : out Ada.Strings.Unbounded.Unbounded_String;
      Revision : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean renames Files.File_System.Transfer.Publish_Staged;

   procedure Discard_Stage (Stage : String) is
   begin
      if not Files.Jobs.Context.Discard_Stage (Stage) then
         Files.Diagnostics.Trace ("Files.Operations", "stage_discard_failed=" & Stage);
      end if;
   end Discard_Stage;

   function Is_Trash_Child (Path : String) return Boolean is separate;

end Files.Operations.Support;
