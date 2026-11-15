with Ada.Real_Time;
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
with Files.Process_Jobs;
with Files.Quick_Look;
with Files.Types;

package body Files.Window_Polls is
   use Ada.Strings.Unbounded;
   use type Files.Types.Item_Kind;

   procedure Ensure_Selected_Item_Extra
     (Model       : in out Files.Model.Window_Model;
      Show_Hidden : Boolean) is
   begin
      if not Files.Model.Background_Transfers (Model)
        and then Files.Model.Selected_Item_Needs_Extra (Model)
      then
         declare
            Item : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
         begin
            Files.Model.Set_Selected_Item_Extra
              (Model,
               Files.File_System.Extra_Info_Of
                 (To_String (Item.Full_Path), Item.Kind, To_String (Item.Filetype), Show_Hidden));
         end;
      end if;
   end Ensure_Selected_Item_Extra;

   --  A size result changes the render revision, and a listing read in
   --  flight (or a paste) must see the revision it was started at. While one
   --  runs, measurements carry on but their results wait in the scan.
   function Folder_Sizes_Paused (Model : Files.Model.Window_Model) return Boolean is
     (Files.Model.Foreground_Job_Is_Active (Model)
      or else Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)));

   procedure Poll_Selected_Item_Extra
     (Model       : in out Files.Model.Window_Model;
      Owner       : Files.Extra_Info_Reader.Requester;
      Show_Hidden : Boolean := True) is
   begin
      if Files.Model.Selected_Item_Needs_Extra (Model) then
         declare
            Item  : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
            Extra : Files.Extra_Info.Info;
            Ready : Boolean;
            Asked : Boolean;
         begin
            --  Taken only when read for the item as listed now: a read of
            --  the file before a refresh relisted it is asked for again.
            Files.Extra_Info_Reader.Take (Owner, Item, Show_Hidden, Extra, Ready, Asked);
            if not Asked then
               Files.Extra_Info_Reader.Request (Owner, Item, Show_Hidden);
            elsif Ready then
               Files.Model.Set_Selected_Item_Extra (Model, Extra);
            end if;
         end;
      end if;
   end Poll_Selected_Item_Extra;

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
      Owner : Files.Preview_Decoder.Requester) is
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
                  Files.Preview_Decoder.Take (Owner, Path, Image, Ready, Asked);
                  if not Asked then
                     Files.Preview_Decoder.Request (Owner, Path, Files.Quick_Look.Preview_Side);
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
                 and then not Files.Model.Folder_Sizes.Cached_For (Model, To_String (Item.Full_Path))
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
      end if;
   end Update_Folder_Size;

end Files.Window_Polls;
