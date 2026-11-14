with Files.Settings.Path_References;
separate (Files.Rendering.Build_Snapshot_Into)
   --  A row per visible item, in the model's order, and a header row before
   --  each band when the details view is grouped.
   procedure Snapshot_Rows is
      use type Files.Model.Clipboard_Mode;
      Cut_Active : constant Boolean :=
        Files.Model.Clipboard.Mode_Of (Model) = Files.Model.Clipboard_Cut;

      --  A set, not a vector: Is_Cut_Pending is asked once per visible item
      --  every frame, so a linear scan of the cut list is O(items x cut) per
      --  frame. Hash the cut paths once and test membership in O(1).
      package Cut_Path_Sets is new Ada.Containers.Hashed_Sets
        (Element_Type        => Ada.Strings.Unbounded.Unbounded_String,
         Hash                => Ada.Strings.Unbounded.Hash,
         Equivalent_Elements => Ada.Strings.Unbounded."=");

      function Build_Cut_Set return Cut_Path_Sets.Set is
         Result : Cut_Path_Sets.Set;
      begin
         if Cut_Active then
            for Path of Files.Model.Clipboard.Paths (Model) loop
               Result.Include (Path);
            end loop;
         end if;
         return Result;
      end Build_Cut_Set;

      --  Built only when rows are built: a selection-only patch reuses
      --  the rows and needs neither this nor Paths below.
      Cut_Paths : Cut_Path_Sets.Set;

      function Is_Cut_Pending (Full_Path : Ada.Strings.Unbounded.Unbounded_String)
        return Boolean is
      begin
         return Cut_Active and then Cut_Paths.Contains (Full_Path);
      end Is_Cut_Pending;
      --  Favorites and labels hashed by path once: each item asks both, and
      --  a scan of the two lists per item made a rebuild O(items x labels).
      Paths : Files.Settings.Path_References.Path_Index;

      --  Rename fields by item index, read once: searching the fields per
      --  row made renaming a whole large folder quadratic.
      type Rename_State is record
         Value  : Ada.Strings.Unbounded.Unbounded_String;
         Cursor : Natural := 0;
      end record;
      function Hash (Index : Natural) return Ada.Containers.Hash_Type is
        (Ada.Containers.Hash_Type'Mod (Index));
      package Rename_Maps is new Ada.Containers.Hashed_Maps
        (Key_Type => Natural, Element_Type => Rename_State, Hash => Hash, Equivalent_Keys => "=");
      Rename_Fields : Rename_Maps.Map;

      procedure Note_Rename (Item_Index : Natural; Value : UString; Cursor : Natural) is
      begin
         --  The first field for an index wins, as the search did.
         if not Rename_Fields.Contains (Item_Index) then
            Rename_Fields.Insert (Item_Index, (Value, Cursor));
         end if;
      end Note_Rename;

      --  Rows are visited in place: a vector of copied items cost a third
      --  of a rebuild in a large folder.
      procedure Add_Row
        (Item       : Files.Items.Directory_Item;
         Item_Index : Natural;
         Selected   : Boolean)
      is
         Full_Path : constant String := To_String (Item.Full_Path);
         Renamed   : constant Rename_Maps.Cursor := Rename_Fields.Find (Item_Index);
         Rename_On : constant Boolean := Rename_Maps.Has_Element (Renamed);
         Rename    : constant Rename_State :=
           (if Rename_On then Rename_Maps.Element (Renamed) else (others => <>));
      begin
         Snapshot.Items.Append
           (Item_Snapshot'
              (Name               => Item.Name,
               Full_Path          => Item.Full_Path,
               Filetype           => Item.Filetype,
               Filetype_Detail    => Filetype_Detail (Item),
               Icon               =>
                 Files.File_Types.Resolve_Icon (Item.Kind, To_String (Item.Filetype), To_String (Item.Icon_Id)),
               Kind               => Item.Kind,
               Size_Available     => Item.Size_Available,
               Size               => Item.Size,
               Creation_Available => Item.Creation_Available,
               Creation_Time      => Item.Creation_Time,
               Modified_Available => Item.Modified_Available,
               Modified_Time      => Item.Modified_Time,
               Permissions        => Item.Permissions,
               Thumbnail_Available => Item.Thumbnail_Available,
               Thumbnail_Path      => Item.Thumbnail_Path,
               Thumbnail_Width     => Item.Thumbnail_Width,
               Thumbnail_Height    => Item.Thumbnail_Height,
               Thumbnail           => (Pixels => Item.Thumbnail_Pixels),
               Metadata_Error     => Item.Metadata_Error,
               Error_Key          => Item.Error_Key,
               Selected           => Selected,
               Visible_Index      => Natural (Snapshot.Items.Length) + 1,
               Cut_Pending        => Is_Cut_Pending (Item.Full_Path),
               Renaming           => Rename_On,
               Rename_Value       => Rename.Value,
               Rename_Cursor      => Rename.Cursor,
               Is_Group_Header    => False,
               Group_Label        => Null_Unbounded_String,
               Is_Favorite        => Files.Settings.Path_References.Is_Favorite (Paths, Full_Path),
               Label              => Files.Settings.Path_References.Label_Of (Paths, Full_Path)));
      end Add_Row;
   begin
      Cut_Paths := Build_Cut_Set;
      Paths := Files.Settings.Path_References.Index_Paths (Settings);
      Files.Model.Rename.For_Each_Field (Model, Note_Rename'Access);
      Snapshot.Items.Reserve_Capacity (Ada.Containers.Count_Type (Snapshot.Visible_Count) + 1);
      Files.Model.For_Each_Visible_Row (Model, Add_Row'Access);

      --  Items arrive in the model's order, which the model keeps sorted by its
      --  sort field. Re-sorting here (with a different collation) once made the
      --  drawn order disagree with the order keyboard and range selection walk.

      --  Grouping composes with the sort. The model keeps its items in band
      --  order (Files.Model.Sync_Grouping), so this only introduces each band
      --  with a non-selectable header row and never reorders: the drawn rows
      --  stay in the order keyboard and range selection walk. The header
      --  carries Visible_Index zero so hit-testing never selects it.
      if Snapshot.View_Mode = Files.Types.Details
        and then Snapshot.Group_By /= Files.Types.No_Grouping
        and then not Snapshot.Items.Is_Empty
      then
         declare
            --  The day the model banded its items by, so headers match the
            --  order even when the clock has passed midnight since.
            Today    : constant Ada.Calendar.Time :=
              (if Files.Model.Grouping_Day (Model) = Files.Types.Unknown_Time
               then Files.Grouping.Day_Start (Snapshot.Now)
               else Files.Model.Grouping_Day (Model));
            Grouped  : Item_Snapshot_Vectors.Vector;
            Previous : Natural := 0;
         begin
            Grouped.Reserve_Capacity (Snapshot.Items.Length + Ada.Containers.Count_Type
              (Files.Grouping.Band_Count (Snapshot.Group_By)));
            for Item of Snapshot.Items loop
               declare
                  Band : constant Positive := Files.Grouping.Band_Of
                    (Snapshot.Group_By, Item.Kind, To_String (Item.Filetype),
                     Item.Modified_Available, Item.Modified_Time,
                     Item.Size_Available, Item.Size, Item.Label, Today);
               begin
                  if Band /= Previous then
                     Grouped.Append
                       (Item_Snapshot'
                          (Is_Group_Header => True,
                           Group_Label     => To_Unbounded_String
                             (Files.Localization.Text (Files.Grouping.Band_Label_Key (Snapshot.Group_By, Band))),
                           Visible_Index   => 0,
                           others          => <>));
                     Previous := Band;
                  end if;
               end;
               Grouped.Append (Item);
            end loop;
            Snapshot.Items.Move (Grouped);
         end;
      end if;
   end Snapshot_Rows;
