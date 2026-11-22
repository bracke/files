with Files.Items;
with Files.Root_Labels;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Files.Commands.Status;
with Files.Grouping;
with Files.Model.Clipboard;
with Files.Model.Context_Menu;
with Files.Model.Folder_Sizes;
with Files.Model.Label_Picker;
with Files.Model.Quick_Look;
with Files.Model.Rename;
with Files.Model.Root_Selector;
with Files.Model.Selection;
with Files.Model.Sort_Menu;
with Files.Model.Status_Samples;
with Files.Model.Tree_Panel;
with Files.Model.Pasting;
with Files.Timing;
separate (Files.Rendering)
   procedure Build_Snapshot_Into
     (Snapshot  : in out View_Snapshot;
      Model     : Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Now       : Ada.Calendar.Time;
      Keep_Rows : Boolean := False)
   is

      function Complete_RGBA_Image
        (Width, Height : Natural;
         Pixel_Count   : Ada.Containers.Count_Type) return Boolean
      is
         Area : Natural;
      begin
         if Width = 0 or else Height = 0
           or else Width > Natural'Last / Height
         then
            return False;
         end if;
         Area := Width * Height;
         return Area <= Natural'Last / 4
           and then Pixel_Count = Ada.Containers.Count_Type (Area * 4);
      end Complete_RGBA_Image;

      --  Kind labels looked up once per rebuild, not once per item: most
      --  items in a folder share a handful of them.
      package Text_Maps is new Ada.Containers.Indefinite_Hashed_Maps
        (Key_Type => String, Element_Type => UString, Hash => Ada.Strings.Hash, Equivalent_Keys => "=");
      Localized : Text_Maps.Map;

      function Cached_Text (Key : String) return UString is
         Found : constant Text_Maps.Cursor := Localized.Find (Key);
      begin
         if Text_Maps.Has_Element (Found) then
            return Text_Maps.Element (Found);
         end if;
         declare
            Value : constant UString := To_Unbounded_String (Files.Localization.Text (Key));
         begin
            Localized.Insert (Key, Value);
            return Value;
         end;
      end Cached_Text;

      function Filetype_Detail
        (Item : Files.Items.Directory_Item)
         return UString
 is separate;

      function Filetype_Extra
        (Item : Files.Items.Directory_Item)
         return UString
 is separate;

      procedure Copy_Fields is separate;
      procedure Snapshot_Overlays is separate;
      procedure Reuse_Rows is separate;
      procedure Patch_Renamed_Rows is separate;
      procedure Snapshot_Rows is separate;
      procedure Snapshot_Selection is separate;
      procedure Snapshot_Info_Pane is separate;
   begin
      --  Start from a blank snapshot, keeping only the rows when asked: the
      --  previous header must not leak into this one.
      declare
         Rows : Item_Snapshot_Vectors.Vector;
         Row_Table : Row_Index_Vectors.Vector;
         Renamed   : Renamed_Row_Maps.Map;
         Rows_Selection   : constant Natural := Snapshot.Rows_Selection_Revision;
         Rows_Rename      : constant Natural := Snapshot.Rows_Rename_Revision;
         Total_Selection  : constant Natural := Snapshot.Total_Selection_Revision;
         Total_Sizes      : constant Natural := Snapshot.Total_Sizes_Revision;
         Total_Bytes      : constant Long_Long_Integer := Snapshot.Selection_Total_Bytes;
         Total_Pending    : constant Boolean := Snapshot.Selection_Total_Pending;
         Info_Key         : constant Info_Pane_Key := Snapshot.Info_Key;
         Info_Rows        : Info_Snapshot_Vectors.Vector;
         Info_Sections    : Coalesced_Section_Vectors.Vector;
         Permissions_Editable : constant Boolean := Snapshot.Permissions_Editable;
         Ownership_Editable   : constant Boolean := Snapshot.Ownership_Editable;
      begin
         if Keep_Rows then
            Info_Rows.Move (Snapshot.Selected_Info);
            Info_Sections.Move (Snapshot.Info_Sections);
            Rows.Move (Snapshot.Items);
            Row_Table.Move (Snapshot.Visible_Rows);
            Renamed.Move (Snapshot.Renamed_Rows);
         end if;
         Snapshot := (others => <>);
         if Keep_Rows then
            Snapshot.Items.Move (Rows);
            Snapshot.Visible_Rows.Move (Row_Table);
            Snapshot.Renamed_Rows.Move (Renamed);
            Snapshot.Rows_Selection_Revision := Rows_Selection;
            Snapshot.Rows_Rename_Revision := Rows_Rename;
            Snapshot.Total_Selection_Revision := Total_Selection;
            Snapshot.Total_Sizes_Revision := Total_Sizes;
            Snapshot.Selection_Total_Bytes := Total_Bytes;
            Snapshot.Selection_Total_Pending := Total_Pending;
            Snapshot.Info_Key := Info_Key;
            Snapshot.Selected_Info.Move (Info_Rows);
            Snapshot.Info_Sections.Move (Info_Sections);
            Snapshot.Permissions_Editable := Permissions_Editable;
            Snapshot.Ownership_Editable := Ownership_Editable;
         end if;
      end;
      Snapshot.Now := Files.Timing.Minute_Start (Now);
      Copy_Fields;
      Snapshot_Overlays;
      --  Kept rows whose flags already show this selection are left alone.
      if not Keep_Rows then
         Snapshot_Rows;
      else
         if Snapshot.Rows_Selection_Revision /= Files.Model.Selection_Revision (Model) then
            Reuse_Rows;
         end if;
         --  Only a rename field's text or caret moved: its rows are written
         --  again, the others stand.
         if Snapshot.Rows_Rename_Revision /= Files.Model.Rename_Revision (Model) then
            Patch_Renamed_Rows;
         end if;
      end if;
      Snapshot.Rows_Selection_Revision := Files.Model.Selection_Revision (Model);
      Snapshot.Rows_Rename_Revision := Files.Model.Rename_Revision (Model);
      Snapshot_Selection;
      declare
         --  An ownership edit shows its buffer and caret in the pane: never
         --  kept.
         Key : constant Info_Pane_Key :=
           (Built     => Files.Model.Focus (Model) /= Files.UI_Types.Focus_Ownership_Input,
            Selection => Files.Model.Selection_Revision (Model),
            Rows      => Files.Model.Rows_Revision (Model),
            Sizes     => Files.Model.Folder_Sizes.Revision (Model),
            Settings  => Files.Model.Settings_Revision (Model),
            Info      => Files.Model.Info_Revision (Model),
            Now       => Snapshot.Now,
            Open      => Snapshot.Info_Pane_Open,
            In_Trash  => Files.Model.Current_Is_Trash (Model));
      begin
         if not (Keep_Rows and then Key.Built and then Snapshot.Info_Key = Key) then
            Snapshot.Selected_Info.Clear;
            Snapshot.Info_Sections.Clear;
            Snapshot.Permissions_Editable := False;
            Snapshot.Ownership_Editable := False;
            if Snapshot.Info_Pane_Open and then Snapshot.Selected_Count > 0 then
               Snapshot_Info_Pane;
            end if;

            --  Formatted here, once a build: the frame lays the pane out and
            --  draws it on every rebuild, hover included.
            if Natural (Snapshot.Selected_Info.Length) >= 2 then
               Snapshot.Info_Sections := Build_Coalesced_Info_Sections (Snapshot);
            end if;
            Snapshot.Info_Key := Key;
         end if;
      end;
      Snapshot.Info_Sections_Built := True;
   end Build_Snapshot_Into;
