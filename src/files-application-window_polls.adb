with Files.Settings.Path_References;
with Files.Model.Info_Pane;
with Files.Model.Tree_Panel;
with Files.Operations.Tree;
with Files.Model.Jobs;
with Files.File_System_Types;
with Ada.Calendar;
with Ada.Real_Time;
with Hostkit.Metadata;
with Files.File_System.Permissions;
with Files.File_System.Trash;
with Files.Model.Status_Samples;
with Files.UI_Types;
with Ada.Strings.Unbounded;
with Guikit.Shared_Bytes;
with Files.Extra_Info;
with Files.File_System;
with Files.Folder_Size;
with Files.Images;
with Files.Items;
with Files.Model.Folder_Sizes;
with Files.Model.Quick_Look;
with Files.Model.Selection;
with Files.Jobs.Process;
with Files.Quick_Look;
with Files.Types;
with Files.File_Types;

package body Files.Application.Window_Polls is
   use Ada.Strings.Unbounded;
   use type Files.Types.Item_Kind;

   --  A size result changes the render revision, and a listing read in
   --  flight (or a paste) must see the revision it was started at. While one
   --  runs, measurements carry on but their results wait in the scan.
   function Folder_Sizes_Paused (Model : Files.Model.Window_Model) return Boolean is
     (Files.Model.Jobs.Foreground_Job_Is_Active (Model)
      or else Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)));

   procedure Poll_Selected_Item_Extra
     (Model       : in out Files.Model.Window_Model;
      Owner       : Files.Application.Extra_Info_Reader.Requester;
      Show_Hidden : Boolean := True) is
   begin
      if Files.Model.Info_Pane.Selected_Item_Needs_Extra (Model) then
         declare
            Item  : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
            Extra : Files.Extra_Info.Info;
            Ready : Boolean;
            Asked : Boolean;
         begin
            --  Taken only when read for the item as listed now: a read of
            --  the file before a refresh relisted it is asked for again.
            Files.Application.Extra_Info_Reader.Take (Owner, Item, Show_Hidden, Extra, Ready, Asked);
            if not Asked then
               Files.Application.Extra_Info_Reader.Request (Owner, Item, Show_Hidden);
            elsif Ready then
               Files.Model.Info_Pane.Set_Selected_Item_Extra (Model, Extra);
            end if;
         end;
      end if;
   end Poll_Selected_Item_Extra;

   procedure Poll_Tree_Children
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Owner    : Files.Application.Tree_Reader.Requester)
   is
      Node : constant Natural := Files.Model.Tree_Panel.Pending_Load (Model);
   begin
      if Node = 0 then
         return;
      end if;
      declare
         Path    : constant String := Files.Model.Tree_Panel.Node_Path (Model, Node);
         Options : constant Files.Types.Listing_Options := Files.Settings.Listing_Options_Of (Settings);
         --  Folders are classified only for a sort by type: otherwise the
         --  maps are not copied on every poll while a read is in flight.
         Classes : constant Files.File_Types.Classification :=
           (if Files.Types."=" (Options.Sort_Field, Files.Types.Sort_Type)
            then Files.Settings.Classification_Of (Settings)
            else (others => <>));
         Load    : Files.File_System.Directory_Load_Result;
         Ready   : Boolean;
         Asked   : Boolean;
      begin
         --  Taken only when read with the settings in force now: a read
         --  made before the hidden filter changed is asked for again.
         Files.Application.Tree_Reader.Take (Owner, Path, Classes, Options, Load, Ready, Asked);
         if not Asked then
            Files.Application.Tree_Reader.Request (Owner, Path, Classes, Options);
         elsif Ready then
            Files.Operations.Tree.Apply_Tree_Children (Model, Node, Load);
         end if;
      end;
   end Poll_Tree_Children;

   procedure Poll_Folder_Sizes (Model : in out Files.Model.Window_Model) is
      Paused : constant Boolean := Folder_Sizes_Paused (Model);
      Taken  : Files.Folder_Size.Measurement_Vectors.Vector;

      procedure Poll (Scan : in out Files.Folder_Size.Session) is
      begin
         Files.Folder_Size.Step (Scan);
         --  Handed over a few times a second, not one by one: each hand-over
         --  gives the window a snapshot to patch.
         if not Paused then
            Files.Folder_Size.Take_Due (Scan, Ada.Real_Time.Clock, Taken);
         end if;
      end Poll;
   begin
      Files.Model.Folder_Sizes.Update_Scan (Model, Poll'Access);
      declare
         Stale : Files.Folder_Size.Measurement_Vectors.Vector;

         procedure Measure_Again (Scan : in out Files.Folder_Size.Session) is
         begin
            for Folder of Stale loop
               Files.Folder_Size.Measure_Again (Scan, To_String (Folder.Path), Folder.Listed);
            end loop;
         end Measure_Again;
      begin
         Files.Model.Folder_Sizes.Note (Model, Taken, Stale);
         if not Stale.Is_Empty then
            Files.Model.Folder_Sizes.Update_Scan (Model, Measure_Again'Access);
         end if;
      end;
   end Poll_Folder_Sizes;

   procedure Poll_Quick_Look
     (Model : in out Files.Model.Window_Model;
      Owner : Files.Application.Preview_Decoder.Requester) is
      use type Files.Quick_Look.Content_Kind;
   begin
      if Files.Model.Quick_Look.Is_Open (Model) then
         declare
            Content : Files.Quick_Look.Quick_Look_Content renames Files.Model.Quick_Look.Content_Of (Model);
         begin
            if Content.Kind = Files.Quick_Look.Image_Content
              and then Guikit.Shared_Bytes.Is_Empty (Content.Image_Pixels)
            then
               declare
                  Path  : constant String := To_String (Content.Image_Path);
                  Image : Files.Images.Decoded_Image;
                  Ready : Boolean;
                  Asked : Boolean;
               begin
                  Files.Application.Preview_Decoder.Take (Owner, Path, Image, Ready, Asked);
                  if not Asked then
                     Files.Application.Preview_Decoder.Request (Owner, Path, Files.Quick_Look.Preview_Side);
                  elsif Ready and then Image.Available then
                     Files.Model.Quick_Look.Set_Image
                       (Model, Path, Guikit.Shared_Bytes.To_Shared (Image.Pixels), Image.Width, Image.Height);
                  end if;
               end;
            end if;
         end;
      end if;
   end Poll_Quick_Look;

   procedure Cancel_Folder_Scan (Model : in out Files.Model.Window_Model) is
      procedure Cancel (Scan : in out Files.Folder_Size.Session) is
         Discarded : Files.Folder_Size.Measurement_Vectors.Vector;
      begin
         Files.Folder_Size.Cancel (Scan);
         Files.Folder_Size.Take_All (Scan, Discarded);
      end Cancel;
   begin
      Files.Model.Folder_Sizes.Update_Scan (Model, Cancel'Access);
   end Cancel_Folder_Scan;

   procedure Update_Folder_Size (Model : in out Files.Model.Window_Model) is
   begin
      --  Retargeted once the read or paste is done: the watch poll's read
      --  comes every few seconds, and cancelling here restarted any folder
      --  slower than that from scratch every time, so it never finished.
      if Folder_Sizes_Paused (Model) then
         return;
      end if;
      declare
         Rows      : constant Natural := Files.Model.Rows_Revision (Model);
         Selection : constant Natural := Files.Model.Selection_Revision (Model);
         Current   : Boolean := False;

         procedure Check (Scan : in out Files.Folder_Size.Session) is
         begin
            Current := Files.Folder_Size.Targets_Set_For (Scan, Rows, Selection);
         end Check;
      begin
         Files.Model.Folder_Sizes.Update_Scan (Model, Check'Access);
         if Current then
            return;
         end if;
      end;
      --  The helper process performs the recursive subtree walk. Here we only
      --  request selected directories; the frame loop polls for completed totals.
      --  Every selected directory is measured -- for any selection, not only when
      --  the info pane is open -- so both the info pane and the bottom bar's
      --  combined total can count folder contents.
      if Files.Model.Selection.Selected_Count (Model) >= 1
        and then not Files.Model.Selection.Includes_Temporary (Model)
      then
         declare
            --  Each with when it was listed, so a size measured before it
            --  changed is told apart (Files.Model.Folder_Sizes.Note).
            Targets : Files.Folder_Size.Target_Vectors.Vector;

            --  Read in place: a copy of a large selection, on every change.
            procedure Add (Item : Files.Items.Directory_Item) is
            begin
               if Item.Kind = Files.Types.Directory_Item
                 and then not Files.Model.Folder_Sizes.Cached_For (Model, Item.Full_Path)
               then
                  Targets.Append (Files.Folder_Size.Target'(Path => Item.Full_Path, Listed => Item.Modified_Time));
               end if;
            end Add;
         begin
            Files.Model.Folder_Sizes.Prune_To_Selection (Model);
            Files.Model.Selection.For_Each_Selected_Item (Model, Add'Access);
            declare
               Rows      : constant Natural := Files.Model.Rows_Revision (Model);
               Selection : constant Natural := Files.Model.Selection_Revision (Model);

               procedure Retarget (Scan : in out Files.Folder_Size.Session) is
               begin
                  Files.Folder_Size.Set_Targets (Scan, Targets);
                  Files.Folder_Size.Note_Targets_Set_For (Scan, Rows, Selection);
               end Retarget;
            begin
               Files.Model.Folder_Sizes.Update_Scan (Model, Retarget'Access);
            end;
         end;
      else
         Cancel_Folder_Scan (Model);
         Files.Model.Folder_Sizes.Clear (Model);
         declare
            --  Read after the clear, which moves the revision: nothing to
            --  measure is a target set too, so the next poll asks for nothing.
            Rows      : constant Natural := Files.Model.Rows_Revision (Model);
            Selection : constant Natural := Files.Model.Selection_Revision (Model);

            procedure Note (Scan : in out Files.Folder_Size.Session) is
            begin
               Files.Folder_Size.Note_Targets_Set_For (Scan, Rows, Selection);
            end Note;
         begin
            Files.Model.Folder_Sizes.Update_Scan (Model, Note'Access);
         end;
      end if;
   end Update_Folder_Size;

   procedure Sample_Volume_Space
     (Model : in out Files.Model.Window_Model)
   is
      Now  : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Path : constant String := Files.Model.Current_Path (Model);
   begin
      if Path = "" then
         --  A view with no folder of its own (Recent) is on no volume: a
         --  capacity query for "" fails here and on Windows may answer for
         --  the working directory's drive. An unchanged unknown touches nothing.
         Files.Model.Status_Samples.Set_Volume_Space (Model, "", (others => <>), Now);
         return;
      end if;
      --  Asked once per folder, before the snapshot is built: matching each
      --  row's path against the stored favorites and labels then asks no
      --  volume.
      if not Files.Model.Status_Samples.Name_Folding_Sampled (Model) then
         Files.Model.Status_Samples.Set_Name_Folding
           (Model, Path, Files.Settings.Path_References.Folding_In (Path));
      end if;
      if not Files.Model.Status_Samples.Volume_Space_Is_Current (Model, Now) then
         declare
            Capacity : constant Hostkit.Metadata.Volume_Capacity := Hostkit.Metadata.Volume_Capacity_Of (Path);
         begin
            Files.Model.Status_Samples.Set_Volume_Space
              (Model,
               Path,
               (Known       => Capacity.Available,
                Free_Bytes  => Capacity.Free_Bytes,
                Total_Bytes => Capacity.Capacity_Bytes),
               Now);
         end;
      end if;
   end Sample_Volume_Space;

   procedure Sample_Host
     (Model : in out Files.Model.Window_Model)
   is
      Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
   begin
      if not Files.Model.Status_Samples.Host_Is_Current (Model, Now) then
         Files.Model.Status_Samples.Set_Host
           (Model,
            Trash_Available       => Files.File_System.Trash.Trash_Files_Directory /= "",
            Permissions_Supported => Files.File_System.Permissions.Supports_Permissions,
            Ownership_Supported   => Files.File_System.Permissions.Supports_Ownership,
            Sampled               => Now);
      end if;
   end Sample_Host;

   procedure Sample_Account_Names
     (Model : in out Files.Model.Window_Model)
   is
      --  Record Item's owner and group names unless they already are.
      procedure Sample (Item : Files.Items.Directory_Item) is
      begin
         if not Item.Ownership_Available then
            return;
         end if;
         if not Files.Model.Status_Samples.Account_Name_Known
           (Model, Files.File_System_Types.User_Account, Item.Owner_Id)
         then
            Files.Model.Status_Samples.Set_Account_Name
              (Model, Files.File_System_Types.User_Account, Item.Owner_Id,
               Files.File_System.Permissions.User_Name_For_Id (Item.Owner_Id));
         end if;
         if not Files.Model.Status_Samples.Account_Name_Known
           (Model, Files.File_System_Types.Group_Account, Item.Group_Id)
         then
            Files.Model.Status_Samples.Set_Account_Name
              (Model, Files.File_System_Types.Group_Account, Item.Group_Id,
               Files.File_System.Permissions.Group_Name_For_Id (Item.Group_Id));
         end if;
      end Sample;
   begin
      if Files.Model.Status_Samples.Account_Names_Current (Model) then
         return;
      end if;
      --  The same items Build_Snapshot lists in the info pane.
      if Files.Model.Info_Pane.Info_Pane_Is_Open (Model) and then Files.Model.Selection.Selected_Count (Model) > 0 then
         declare
            Items : constant Files.Items.Item_Vectors.Vector :=
              Files.Model.Selection.Selected_Items (Model, Limit => Files.UI_Types.Max_Info_Items);
         begin
            if Items.Is_Empty then
               Sample (Files.Model.Selection.Selected_Item (Model));
            end if;
            for Item of Items loop
               Sample (Item);
            end loop;
         end;
      end if;
      --  After any Set_Account_Name above, so its revision bump is covered.
      Files.Model.Status_Samples.Note_Account_Names_Sampled (Model);
   end Sample_Account_Names;

end Files.Application.Window_Polls;
