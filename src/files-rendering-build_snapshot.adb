with Files.Grouping;
separate (Files.Rendering)
   function Build_Snapshot
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return View_Snapshot
   is
      --  Selected items whose details the info pane lists.
      Max_Info_Items : constant := 100;
      Snapshot : View_Snapshot;

      function Natural_Text (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Natural_Text;

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

      Theme : constant Render_Theme :=
        (case Settings.Theme is
            when Files.Settings.Theme_High_Contrast => High_Contrast_Theme,
            when others => Default_Theme);

      function Filetype_Detail
        (Item : Files.File_System.Directory_Item)
         return UString
 is separate;

      function Filetype_Extra
        (Item : Files.File_System.Directory_Item)
         return UString
 is separate;

      function Root_Display_Label
        (Path  : String;
         Label : String)
         return String is separate;
      --  The selection, copied once for the selection total and the info pane.
      Selected : Files.File_System.Item_Vectors.Vector;
   begin
      Snapshot.Current_Path := To_Unbounded_String (Files.Model.Current_Path (Model));
      Snapshot.Current_Path_Is_Favorite :=
        Files.Settings.Is_Favorite (Settings, Files.Model.Current_Path (Model));
      Snapshot.In_Recent_View := Files.Model.In_Recent_View (Model);
      Snapshot.View_Mode := Files.Model.View_Mode_Of (Model);
      Snapshot.Sort_Field := Files.Model.Sort_Field_Of (Model);
      Snapshot.Sort_Ascending := Files.Model.Sort_Is_Ascending (Model);
      Snapshot.Sort_Menu_Open := Files.Model.Sort_Menu_Is_Open (Model);
      Snapshot.Sort_Menu_Highlight := Files.Model.Sort_Menu_Highlight (Model);
      Snapshot.Show_Extensions := Settings.Show_File_Extensions;
      Snapshot.Show_Used_Space := Settings.Show_Used_Space;
      Snapshot.Show_Space_Bar := Settings.Show_Space_Bar;
      Snapshot.Detail_Columns_Visible := Settings.Column_Visible;
      Snapshot.Detail_Column_Widths := Settings.Column_Widths;
      Snapshot.Detail_Column_Order := Settings.Column_Order;
      Snapshot.Group_By := Settings.Group_By;
      Snapshot.Item_Count := Files.Model.Item_Count (Model);
      Snapshot.Visible_Count := Files.Model.Visible_Count (Model);
      Snapshot.Hidden_Count := Files.Model.Hidden_Item_Count (Model);
      Snapshot.Selected_Count := Files.Model.Selected_Count (Model);
      Snapshot.Primary_Selected_Visible_Index :=
        Files.Model.Selected_Index (Model);
      declare
         --  Free-space comes from the current directory's filesystem via a
         --  statvfs syscall. The platform accessor reports Available = False when
         --  the volume cannot be measured (non-Linux stubs, unreadable paths), so
         --  a bogus zero is never shown as a known value. Cache it per path so a
         --  scroll (same directory) does not re-run the syscall every frame;
         --  navigating to another directory refreshes it.
         Path : constant String := Files.Model.Current_Path (Model);
         Now  : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         use type Ada.Calendar.Time;
      begin
         if not Free_Space_Cache_Is_Current (Path)
         then
            Cached_Free_Cap := Hostkit.Metadata.Volume_Capacity_Of (Path);
            Cached_Free_Path := Ada.Strings.Unbounded.To_Unbounded_String (Path);
            Cached_Free_Time := Now;
            Cached_Free_Ready := True;
         end if;

         Snapshot.Free_Space_Known := Cached_Free_Cap.Available;
         Snapshot.Free_Space_Bytes := Cached_Free_Cap.Free_Bytes;
         Snapshot.Total_Space_Bytes := Cached_Free_Cap.Capacity_Bytes;
      end;
      Snapshot.Filter_Text := To_Unbounded_String (Files.Model.Filter_Text (Model));
      Snapshot.Search_Scope := Files.Model.Search_Scope_Of (Model);
      Snapshot.Search_Results_Active := Files.Model.Search_Results_Are_Active (Model);
      Snapshot.Last_Error_Key := To_Unbounded_String (Files.Model.Last_Error_Key (Model));
      Snapshot.Focus := Files.Model.Focus (Model);
      Snapshot.Text_Cursor_Position := Files.Model.Text_Cursor_Position (Model);
      Snapshot.Path_Input_Text := To_Unbounded_String (Files.Model.Path_Input_Text (Model));
      Snapshot.Path_Input_Valid := Files.Model.Path_Input_Is_Valid (Model);
      Snapshot.Path_Input_Error_Key := To_Unbounded_String (Files.Model.Path_Input_Error_Key (Model));
      Snapshot.Rename_Active := Files.Model.Rename_Is_Active (Model);
      Snapshot.Temporary_Item_Active := Files.Model.Temporary_Item_Is_Active (Model);
      Snapshot.Temporary_Item_Name := To_Unbounded_String (Files.Model.Temporary_Item_Name (Model));
      Snapshot.Info_Pane_Open := Files.Model.Info_Pane_Is_Open (Model);
      Snapshot.Settings_Pane_Open := Files.Model.Settings_Pane_Is_Open (Model);
      Snapshot.Settings_Icon_Theme := Settings.Icon_Theme_Name;
      Snapshot.Info_Pane_Scroll_Lines := Files.Model.Info_Pane_Scroll_Lines (Model);
      Snapshot.Main_View_Scroll_Lines := Files.Model.Main_View_Scroll_Lines (Model);
      Snapshot.Context_Menu_Open := Files.Model.Context_Menu_Is_Open (Model);
      Snapshot.Context_Menu_Highlight := Files.Model.Context_Menu_Highlight (Model);
      Snapshot.Context_Menu_X := Files.Model.Context_Menu_X (Model);
      Snapshot.Context_Menu_Y := Files.Model.Context_Menu_Y (Model);
      Snapshot.Context_Menu_Target := Files.Model.Context_Menu_Target_Of (Model);
      Snapshot.Context_Menu_Item_Index := Files.Model.Context_Menu_Item_Index (Model);
      Snapshot.Paste_Conflict_Open := Files.Model.Paste_Conflict_Is_Active (Model);
      Snapshot.Paste_Conflict_Name := To_Unbounded_String (Files.Model.Paste_Conflict_Name (Model));
      Snapshot.Paste_Conflict_Apply_All := Files.Model.Paste_Conflict_Apply_All (Model);
      Snapshot.Paste_Progress_Open := Files.Model.Paste_Execution_Is_Active (Model);
      Snapshot.Paste_Progress_Operation_Label := To_Unbounded_String (Files.Model.Background_Operation_Label (Model));
      Snapshot.Paste_Progress_Done := Files.Model.Paste_Execution_Done (Model);
      Snapshot.Paste_Progress_Total := Files.Model.Paste_Execution_Total (Model);
      Snapshot.Paste_Progress_Name :=
        To_Unbounded_String (Files.Model.Paste_Execution_Current_Name (Model));
      declare
         use type Files.File_System.Drop_Import_Mode;
      begin
         Snapshot.Paste_Progress_Moving :=
           Files.Model.Paste_Execution_Mode (Model) = Files.File_System.Drop_Move;
      end;
      Snapshot.Theme_Name := Theme.Name;
      Snapshot.Theme_High_Contrast := Theme.High_Contrast;
      Snapshot.Theme_Palette :=
        (case Settings.Theme is
            when Files.Settings.Theme_Dark          => Theme_Dark,
            when Files.Settings.Theme_Light         => Theme_Light,
            when Files.Settings.Theme_High_Contrast => Theme_High_Contrast);
      Snapshot.Theme_Focus_Ring := Theme.Focus_Ring;
      --  The command palette owns its query/selection/results and renders itself
      --  (Guikit.Command_Palette, merged at the window layer); the snapshot only
      --  records that it is open, for overlay hit-testing.
      Snapshot.Command_Palette_Open := Files.Model.Command_Palette_Is_Open (Model);
      --  The root selector remains logically open while the palette temporarily
      --  takes focus, but must not be painted underneath it: overlay rectangles
      --  and overlay text are separate GPU passes, so its text would otherwise
      --  bleed through the palette panel.
      Snapshot.Root_Selector_Open :=
        Files.Model.Root_Selector_Is_Open (Model)
        and then not Snapshot.Command_Palette_Open;
      Snapshot.Root_Selected_Index := Files.Model.Root_Selected_Index (Model);

      Snapshot.Label_Picker_Open := Files.Model.Label_Picker_Is_Open (Model);
      Snapshot.Label_Picker_Highlight := Files.Model.Label_Picker_Highlight (Model);
      Snapshot.Quick_Look_Open := Files.Model.Quick_Look_Is_Open (Model);
      if Snapshot.Quick_Look_Open then
         declare
            Content : constant Files.Quick_Look.Quick_Look_Content :=
              Files.Model.Quick_Look_Content_Of (Model);
            Item    : constant Files.File_System.Directory_Item :=
              Files.Model.Selected_Item (Model);
         begin
            Snapshot.Quick_Look_Kind           := Content.Kind;
            Snapshot.Quick_Look_Name           := Content.Name;
            Snapshot.Quick_Look_Type           := Content.Filetype;
            Snapshot.Quick_Look_Icon_Id        := Content.Icon_Id;
            Snapshot.Quick_Look_Size_Available := Content.Size_Available;
            Snapshot.Quick_Look_Size           := Content.Size;
            Snapshot.Quick_Look_Text_Lines     := Content.Text_Lines;
            Snapshot.Quick_Look_Text_Truncated := Content.Text_Truncated;
            --  Prefer the original image decoded at preview resolution; fall
            --  back to the item's small thumbnail when decoding was unavailable.
            if Content.Kind = Files.Quick_Look.Image_Content
              and then Complete_RGBA_Image
                (Content.Image_Width, Content.Image_Height,
                 Content.Image_Pixels.Length)
            then
               Snapshot.Quick_Look_Image_Width  := Content.Image_Width;
               Snapshot.Quick_Look_Image_Height := Content.Image_Height;
               Snapshot.Quick_Look_Image_Pixels := Content.Image_Pixels;
            elsif Content.Kind = Files.Quick_Look.Image_Content
              and then Item.Thumbnail_Available
            then
               Snapshot.Quick_Look_Image_Width  := Item.Thumbnail_Width;
               Snapshot.Quick_Look_Image_Height := Item.Thumbnail_Height;
               Snapshot.Quick_Look_Image_Pixels := Files.Shared_Bytes.To_Vector (Item.Thumbnail_Pixels);
            end if;
         end;
      end if;

      for Id in Files.Commands.Registered_Command_Id loop
         Snapshot.Command_Enabled (Id) := Files.Commands.Is_Enabled (Id, Model);
      end loop;

      for Index in 1 .. Files.Model.Root_Count (Model) loop
         declare
            Root_Path  : constant String := Files.Model.Root_Path (Model, Index);
            Root_Label : constant String := Files.Model.Root_Label (Model, Index);
         begin
            Snapshot.Root_Paths.Append (To_Unbounded_String (Root_Path));
            Snapshot.Root_Labels.Append (To_Unbounded_String (Root_Display_Label (Root_Path, Root_Label)));
         end;
      end loop;

      Snapshot.Tree_Panel_Open := Files.Model.Tree_Panel_Is_Open (Model);
      Snapshot.Tree_Panel_Scroll_Rows :=
        Files.Model.Tree_Panel_Scroll_Rows (Model);
      Snapshot.Tree_Rows := Files.Model.Tree_Visible_Rows (Model);
      Snapshot.Tree_Pick_Active := Files.Model.Tree_Pick_Is_Active (Model);
      Snapshot.Tree_Pick_Moving :=
        Files.Model.Tree_Pick_Mode_Of (Model) = Files.Model.Pick_Move;
      Snapshot.Tree_Pick_Target := To_Unbounded_String (Files.Model.Tree_Pick_Target (Model));
      Snapshot.Tree_Keyboard_Active := Files.Model.Tree_Has_Keyboard (Model);
      Snapshot.Tree_Cursor := To_Unbounded_String (Files.Model.Tree_Cursor (Model));
      Snapshot.Breadcrumb_Segments :=
        Files.Breadcrumbs.Segments (Files.Model.Current_Path (Model));

      declare
         use type Files.Model.Clipboard_Mode;
         Cut_Active : constant Boolean :=
           Files.Model.Clipboard_Mode_Of (Model) = Files.Model.Clipboard_Cut;

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
               for Path of Files.Model.Clipboard_Paths (Model) loop
                  Result.Include (Path);
               end loop;
            end if;
            return Result;
         end Build_Cut_Set;

         Cut_Paths : constant Cut_Path_Sets.Set := Build_Cut_Set;

         function Is_Cut_Pending (Full_Path : Ada.Strings.Unbounded.Unbounded_String)
           return Boolean is
         begin
            return Cut_Active and then Cut_Paths.Contains (Full_Path);
         end Is_Cut_Pending;
         Rows : constant Files.Model.Visible_Row_Vectors.Vector := Files.Model.Visible_Rows (Model);
      begin
         for Index in Rows.First_Index .. Rows.Last_Index loop
            declare
               Row  : Files.Model.Visible_Row renames Rows (Index);
               Item : Files.File_System.Directory_Item renames Row.Item;
               Rename_On     : Boolean;
               Rename_Value  : Ada.Strings.Unbounded.Unbounded_String;
               Rename_Cursor : Natural;
            begin
               Files.Model.Rename_State_For_Item
                 (Model, Row.Item_Index, Rename_On, Rename_Value, Rename_Cursor);
               Snapshot.Items.Append
                 (Item_Snapshot'
                    (Name               => Item.Name,
                     Name_Lower         =>
                       To_Unbounded_String (Files.Types.To_Lower (To_String (Item.Name))),
                     Filetype           => Item.Filetype,
                     Filetype_Detail    => Filetype_Detail (Item),
                     Icon_Id            => Item.Icon_Id,
                     Kind               => Item.Kind,
                     Size_Available     => Item.Size_Available,
                     Size               => Item.Size,
                     Creation_Available => Item.Creation_Available,
                     Creation_Time      => Item.Creation_Time,
                     Modified_Available => Item.Modified_Available,
                     Modified_Time      => Item.Modified_Time,
                     Permissions        => Item.Permissions,
                     Filetype_Extra     => Filetype_Extra (Item),
                     Thumbnail_Available => Item.Thumbnail_Available,
                     Thumbnail_Path      => Item.Thumbnail_Path,
                     Thumbnail_Width     => Item.Thumbnail_Width,
                     Thumbnail_Height    => Item.Thumbnail_Height,
                     Thumbnail           => (Pixels => Item.Thumbnail_Pixels),
                     Metadata_Error     => Item.Metadata_Error,
                     Error_Key          => Item.Error_Key,
                     Selected           => Row.Selected,
                     Visible_Index      => Index,
                     Cut_Pending        => Is_Cut_Pending (Item.Full_Path),
                     Renaming           => Rename_On,
                     Rename_Value       => Rename_Value,
                     Rename_Cursor      => Rename_Cursor,
                     Is_Group_Header    => False,
                     Group_Label        => Null_Unbounded_String,
                     Is_Favorite        =>
                       Files.Settings.Is_Favorite (Settings, To_String (Item.Full_Path)),
                     Label              =>
                       Files.Settings.Label_Of (Settings, To_String (Item.Full_Path))));
            end;
         end loop;
      end;

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
            Today    : constant Ada.Calendar.Time := Files.Grouping.Day_Start (Ada.Calendar.Clock);
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
            Snapshot.Items := Grouped;
         end;
      end if;

      --  Combined selection total: every selected file's size plus the recursive
      --  size of each selected folder. Computed for any selection (not only when
      --  the info pane is open) so the bottom bar's total counts folder contents.
      --  Folders not yet measured mark the total pending (still growing).
      if Files.Model.Selected_Count (Model) > 0 then
         Selected := Files.Model.Selected_Items (Model);
      end if;
      if Files.Model.Selected_Count (Model) > 0 then
         declare
            Total   : Long_Long_Integer := 0;
            Pending : Boolean := False;

            procedure Add (Amount : Long_Long_Integer) is
            begin
               if Amount > 0 and then Total <= Long_Long_Integer'Last - Amount then
                  Total := Total + Amount;
               elsif Amount > 0 then
                  Total := Long_Long_Integer'Last;
               end if;
            end Add;
         begin
            for Item of Selected loop
               if Item.Kind = Files.Types.Directory_Item then
                  if Files.Model.Folder_Size_Cached_For (Model, To_String (Item.Full_Path)) then
                     Add (Files.Model.Folder_Size_Value
                            (Model, To_String (Item.Full_Path)).Total_Bytes);
                  else
                     Pending := True;
                  end if;
               elsif Item.Size_Available then
                  Add (Item.Size);
               end if;
            end loop;
            Snapshot.Selection_Total_Bytes := Total;
            Snapshot.Selection_Total_Pending := Pending;
         end;
      end if;

      if Snapshot.Info_Pane_Open and then Files.Model.Selected_Count (Model) > 0 then
         declare
            Items : Files.File_System.Item_Vectors.Vector renames Selected;

            function Build_Info
              (Item : Files.File_System.Directory_Item)
               return Info_Snapshot
            is
               Is_Directory : constant Boolean := Item.Kind = Files.Types.Directory_Item;
               Info : Info_Snapshot :=
                 (Name               => Item.Name,
                  Filetype           => Item.Filetype,
                  Size_Available     => Item.Size_Available,
                  Size               => Item.Size,
                  Creation_Available => Item.Creation_Available,
                  Creation_Time      => Item.Creation_Time,
                  Modified_Available => Item.Modified_Available,
                  Modified_Time      => Item.Modified_Time,
                  Permissions        => Item.Permissions,
                  Mode_Available     => Item.Mode_Available,
                  Mode_Bits          => Item.Mode_Bits,
                  Ownership_Available => Item.Ownership_Available,
                  Owner_Id           => Item.Owner_Id,
                  Group_Id           => Item.Group_Id,
                  Is_Directory       => Is_Directory,
                  Metadata_Error     => Item.Metadata_Error,
                  Error_Key          => Item.Error_Key,
                  Filetype_Detail    => Filetype_Detail (Item),
                  Filetype_Extra     => Filetype_Extra (Item),
                  others             => <>);
            begin
               if Is_Directory
                 and then Files.Model.Folder_Size_Cached_For (Model, To_String (Item.Full_Path))
               then
                  declare
                     Measured : constant Files.File_System.Directory_Size_Result :=
                       Files.Model.Folder_Size_Value (Model, To_String (Item.Full_Path));
                  begin
                     Info.Folder_Size_Available := Measured.Available;
                     Info.Folder_Size_Bytes     := Measured.Total_Bytes;
                     Info.Folder_File_Count      := Measured.File_Count;
                     Info.Folder_Item_Count      := Measured.Item_Count;
                     Info.Folder_Size_Capped     := Measured.Capped;
                  end;
               end if;

               --  Resolve owner/group names for display (cached per session).
               if Item.Ownership_Available then
                  Info.Owner_Name :=
                    To_Unbounded_String (Files.File_System.User_Name_For_Id (Item.Owner_Id));
                  Info.Group_Name :=
                    To_Unbounded_String (Files.File_System.Group_Name_For_Id (Item.Group_Id));
               end if;

               return Info;
            end Build_Info;

            Single_Item : constant Files.File_System.Directory_Item :=
              Files.Model.Selected_Item (Model);
            In_Trash    : constant Boolean :=
              Files.File_System.Is_Trash_Files_Directory
                (Files.Model.Current_Path (Model));
         begin
            Snapshot.Permissions_Editable :=
              Files.Model.Selected_Count (Model) = 1
              and then not In_Trash
              and then Files.File_System.Supports_Permissions
              and then Single_Item.Mode_Available;

            Snapshot.Ownership_Editable :=
              Files.Model.Selected_Count (Model) = 1
              and then not In_Trash
              and then Files.File_System.Supports_Ownership
              and then Single_Item.Ownership_Available;

            if Items.Is_Empty then
               Snapshot.Selected_Info.Append (Build_Info (Single_Item));
            else
               --  The coalesced pane lists one row per item per field, and is
               --  laid out and drawn on every rebuild (hover included). Past a
               --  hundred items the list is unreadable anyway, while Select All
               --  in a large folder formatted every item's dates and sizes per
               --  mouse move; the selection count shows the full extent.
               for Item of Items loop
                  exit when Natural (Snapshot.Selected_Info.Length) >= Max_Info_Items;
                  Snapshot.Selected_Info.Append (Build_Info (Item));
               end loop;
            end if;

            --  Reflect an active ownership edit on the single selected item so
            --  the info pane shows the editor buffer and draws the caret.
            if Snapshot.Ownership_Editable
              and then Natural (Snapshot.Selected_Info.Length) = 1
              and then Files.Model.Focus (Model) = Files.Types.Focus_Ownership_Input
            then
               declare
                  Editing : Info_Snapshot := Snapshot.Selected_Info.First_Element;
               begin
                  Editing.Ownership_Buffer :=
                    To_Unbounded_String (Files.Model.Ownership_Input_Text (Model));
                  if Files.Model.Ownership_Editing_Group (Model) then
                     Editing.Group_Editing := True;
                  else
                     Editing.Owner_Editing := True;
                  end if;
                  Snapshot.Selected_Info.Replace_Element
                    (Snapshot.Selected_Info.First_Index, Editing);
               end;
            end if;
         end;
      end if;

      return Snapshot;
   end Build_Snapshot;
