with Files.File_System.Permissions;
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
      procedure Snapshot_Rows is separate;
      procedure Snapshot_Selection is separate;
      procedure Snapshot_Info_Pane is separate;
   begin
      --  Start from a blank snapshot, keeping only the rows when asked: the
      --  previous header must not leak into this one.
      declare
         Rows : Item_Snapshot_Vectors.Vector;
      begin
         if Keep_Rows then
            Rows.Move (Snapshot.Items);
         end if;
         Snapshot := (others => <>);
         if Keep_Rows then
            Snapshot.Items.Move (Rows);
         end if;
      end;
      Snapshot.Now := Files.Timing.Minute_Start (Now);
      Copy_Fields;
      Snapshot_Overlays;
      if Keep_Rows then
         Reuse_Rows;
      else
         Snapshot_Rows;
      end if;
      Snapshot_Selection;
      if Snapshot.Info_Pane_Open and then Snapshot.Selected_Count > 0 then
         Snapshot_Info_Pane;
      end if;

      --  Formatted here, once a build: the frame lays the pane out and draws
      --  it on every rebuild, hover included.
      if Natural (Snapshot.Selected_Info.Length) >= 2 then
         Snapshot.Info_Sections := Build_Coalesced_Info_Sections (Snapshot);
      end if;
      Snapshot.Info_Sections_Built := True;
   end Build_Snapshot_Into;
