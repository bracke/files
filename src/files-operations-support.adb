with Files.Model.Jobs;
with Files.File_System.Trash;
with Files.Model.Recent;
with Files.Command_Reasons;
with Files.Jobs.Context;
with Ada.Directories;
with Files.Diagnostics;

with Files.File_System.Transfer;
with Files.Refresh;
with Files.IO.Fs_Primitives;
with Files.Leaf_Names;
with Hostkit.Fs;
with Files.Model.Selection;
with Files.Model.Filtering;
with Files.File_System.Search;
with Files.Items;
with Files.File_System_Types;
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

   --  Load the folder at Path to show it: listed with Settings'
   --  classification and listing options, its new images' thumbnails left
   --  to a background listing (Load_Directory_Deferring_Thumbnails). The
   --  one load every view change and in-place reload makes.
   function Load_Folder
     (Settings : Files.Settings.Settings_Model;
      Path     : String)
      return Files.File_System.Directory_Load_Result;

   --  What every folder loaded to show in a view moved to it ends with,
   --  once Load_And_Show's caller installed Load's items: the trash flag
   --  settled, then the listing settled as every listing shown is
   --  (Files.Refresh.Settle_Listed): the signature the watch compares with
   --  stored, the images still lacking a thumbnail owed to a background
   --  listing (which the window's poll pays through
   --  Files.Refresh.Resume_Owed, so nothing waits on decoding), the error
   --  line cleared and the selected item's details read. A folder read
   --  again in place goes through Files.Refresh.Reinstall_Listing instead,
   --  which keeps the place in it and ends the same way.
   procedure Show_Loaded_Folder
     (Model       : in out Files.Model.Window_Model;
      Load        : Files.File_System.Directory_Load_Result;
      Show_Hidden : Boolean);

   function Reloads_In_Background (Model : Files.Model.Window_Model) return Boolean is
     (Files.Model.Jobs.Background_Transfers (Model));

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
         --  Search results are searched again there, not here: a search
         --  may read every file below the folder.
         return Files.Refresh.Start
           (Model, Settings, Force => True, Select_Name => Select_Name, Select_Path => Select_Path,
            Search_Again => True);
      end if;
      Reload_In_Place :
      declare
         use type Files.UI_Types.Search_Scope;
         --  The Recent view has no backing directory (Current_Path is
         --  empty): it is rebuilt from the recorded recent paths
         --  (Load_Recent_Items), not loaded. Search results have no folder
         --  listing to reload: the search runs again, so what the
         --  operation changed shows among them and they stay shown.
         Recent   : constant Boolean := Files.Model.Recent.In_Recent_View (Model);
         Searched : constant Files.UI_Types.Search_Scope :=
           (if not Recent and then Files.Model.Filtering.Search_Results_Are_Active (Model)
            then Files.Model.Filtering.Search_Scope_Of (Model)
            else Files.UI_Types.Filter_Here);
         Root      : constant String := Files.Model.Current_Path (Model);
         Items     : Files.Items.Item_Vectors.Vector;
         Signature : Files.File_System_Types.Directory_Signature := Files.Model.Directory_Signature_Of (Model);
         Notice    : Unbounded_String;
      begin
         if Recent then
            Items := Files.Refresh.Load_Recent_Items (Settings);
         elsif Searched /= Files.UI_Types.Filter_Here then
            declare
               Found : constant Files.File_System.Search.Folder_Search_Result :=
                 Files.File_System.Search.Search_Folder
                   (Root, Files.Model.Filtering.Search_Query (Model), Searched,
                    Files.Settings.Classification_Of (Settings), Files.Settings.Listing_Options_Of (Settings));
            begin
               if not Found.Success then
                  Files.Model.Set_Error (Model, To_String (Found.Error_Key));
                  return Make_Result (Operation_Failed, To_String (Found.Error_Key), Root);
               end if;
               Items := Found.Items;
               Signature := Found.Signature;
               Notice := Found.Notice;
            end;
         else
            declare
               Load : constant Files.File_System.Directory_Load_Result := Load_Folder (Settings, Root);
            begin
               if not Load.Success then
                  Files.Model.Set_Error (Model, To_String (Load.Error_Key));
                  return Make_Result (Operation_Failed, To_String (Load.Error_Key), Root);
               end if;
               Items := Load.Items;
               Signature := Load.Signature;
            end;
         end if;
         --  A reload runs after every operation: it must not decode each
         --  new image while the UI waits, as no folder shown does. Search
         --  results keep their selection where it still is.
         Files.Refresh.Reinstall_Listing
           (Model, Items, Signature,
            Recent         => Recent,
            Searched       => Searched,
            Query          => Files.Model.Filtering.Search_Query (Model),
            Select_Path    => Select_Path,
            Select_Name    => Select_Name,
            Keep_Selection => Preserve_Selection or else Searched /= Files.UI_Types.Filter_Here,
            Owe_Thumbnails => not Recent and then Searched = Files.UI_Types.Filter_Here,
            Show_Hidden    => Settings.Show_Hidden_Files,
            Error_Line     => To_String (Notice));
         return Make_Result (Operation_Success, Path => Root);
      end Reload_In_Place;
   end Reload_Current_Directory;

   function Search_Current_Folder
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Scope    : Files.UI_Types.Tree_Search_Scope;
      Query    : String)
      return Operation_Result
   is
      Root  : constant String := Files.Model.Current_Path (Model);
      Found : constant Files.File_System.Search.Folder_Search_Result :=
        Files.File_System.Search.Search_Folder
          (Root, Query, Scope,
           Files.Settings.Classification_Of (Settings), Files.Settings.Listing_Options_Of (Settings));
   begin
      if not Found.Success then
         Files.Model.Set_Error (Model, To_String (Found.Error_Key));
         return Make_Result (Operation_Failed, To_String (Found.Error_Key), Root);
      end if;
      --  New results are the view now, a listing owed to the folder
      --  settled; a partial answer is still shown, with a notice that it is
      --  one: a limit cut it short, or something under the root went
      --  unsearched.
      Files.Refresh.Reinstall_Listing
        (Model, Found.Items, Found.Signature,
         Searched    => Scope,
         Query       => Query,
         New_Results => True,
         Show_Hidden => Settings.Show_Hidden_Files,
         Error_Line  => To_String (Found.Notice));
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

   function Reload_Saying
     (Model       : in out Files.Model.Window_Model;
      Settings    : Files.Settings.Settings_Model;
      Error_Key   : String;
      Path        : String := "";
      Select_Name : String := "";
      Select_Path : String := "")
      return Operation_Result
   is
      Reload : Operation_Result;
   begin
      Files.Model.Set_Error (Model, Error_Key, Path);
      Reload := Reload_Current_Directory (Model, Settings, Select_Name, Select_Path => Select_Path);
      if Reload.Status = Operation_Success and then not Reloads_In_Background (Model) and then Error_Key /= "" then
         Files.Model.Set_Error (Model, Error_Key, Path);
      end if;
      return Reload;
   end Reload_Saying;

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

   function Load_Folder
     (Settings : Files.Settings.Settings_Model;
      Path     : String)
      return Files.File_System.Directory_Load_Result is
     (Files.File_System.Load_Directory_Deferring_Thumbnails
        (Path, Files.Settings.Classification_Of (Settings), Files.Settings.Listing_Options_Of (Settings)));

   procedure Show_Loaded_Folder
     (Model       : in out Files.Model.Window_Model;
      Load        : Files.File_System.Directory_Load_Result;
      Show_Hidden : Boolean) is
   begin
      Settle_Current_Is_Trash (Model);
      Files.Refresh.Settle_Listed
        (Model, Load.Items, Load.Signature,
         Owe_Thumbnails => True,
         Error_Line     => "",
         Show_Hidden    => Show_Hidden);
   end Show_Loaded_Folder;

   function Load_And_Show
     (Model       : in out Files.Model.Window_Model;
      Settings    : Files.Settings.Settings_Model;
      Path        : String;
      Install     : not null access procedure
        (Model : in out Files.Model.Window_Model;
         Load  : Files.File_System.Directory_Load_Result);
      Say_Failure : Boolean := True)
      return Operation_Result
   is
      Load : constant Files.File_System.Directory_Load_Result := Load_Folder (Settings, Path);
   begin
      if not Load.Success then
         if Say_Failure then
            Files.Model.Set_Error (Model, To_String (Load.Error_Key));
         end if;
         return Make_Result (Operation_Failed, To_String (Load.Error_Key), Path);
      end if;
      Install (Model, Load);
      Show_Loaded_Folder (Model, Load, Settings.Show_Hidden_Files);
      return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
   end Load_And_Show;

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
