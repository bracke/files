separate (Files.Rendering)
   function Build_Snapshot
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return View_Snapshot
   is
      Snapshot : View_Snapshot;

      function Natural_Text (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Natural_Text;

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
         if not Cached_Free_Ready
           or else Ada.Strings.Unbounded.To_String (Cached_Free_Path) /= Path
           or else Now - Cached_Free_Time > Free_Space_Refresh_Interval
         then
            Cached_Free_Cap := Files.Platform.Metadata.Volume_Capacity_Of (Path);
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
      Snapshot.Root_Selector_Open := Files.Model.Root_Selector_Is_Open (Model);
      Snapshot.Root_Selected_Index := Files.Model.Root_Selected_Index (Model);
      --  The command palette owns its query/selection/results and renders itself
      --  (Guikit.Command_Palette, merged at the window layer); the snapshot only
      --  records that it is open, for overlay hit-testing.
      Snapshot.Command_Palette_Open := Files.Model.Command_Palette_Is_Open (Model);

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
              and then Content.Image_Width > 0
              and then Content.Image_Height > 0
              and then Natural (Content.Image_Pixels.Length)
                       = Content.Image_Width * Content.Image_Height * 4
            then
               Snapshot.Quick_Look_Image_Width  := Content.Image_Width;
               Snapshot.Quick_Look_Image_Height := Content.Image_Height;
               Snapshot.Quick_Look_Image_Pixels := Content.Image_Pixels;
            elsif Content.Kind = Files.Quick_Look.Image_Content
              and then Item.Thumbnail_Available
            then
               Snapshot.Quick_Look_Image_Width  := Item.Thumbnail_Width;
               Snapshot.Quick_Look_Image_Height := Item.Thumbnail_Height;
               Snapshot.Quick_Look_Image_Pixels := Item.Thumbnail_Pixels;
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
      Snapshot.Tree_Rows := Files.Model.Tree_Visible_Rows (Model);
      Snapshot.Tree_Pick_Active := Files.Model.Tree_Pick_Is_Active (Model);
      Snapshot.Tree_Pick_Moving :=
        Files.Model.Tree_Pick_Mode_Of (Model) = Files.Model.Pick_Move;
      Snapshot.Tree_Pick_Target := To_Unbounded_String (Files.Model.Tree_Pick_Target (Model));
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
               Files.Model.Rename_State_For_Visible
                 (Model, Index, Rename_On, Rename_Value, Rename_Cursor);
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

      declare
         function Name_Less (Left : Item_Snapshot; Right : Item_Snapshot) return Boolean is
         begin
            --  Name_Lower is the case-folded Name, precomputed once per item at
            --  build; case-sensitive Name breaks ties so distinct-case names
            --  stay ordered deterministically.
            if Left.Name_Lower /= Right.Name_Lower then
               return Left.Name_Lower < Right.Name_Lower;
            else
               return Left.Name < Right.Name;
            end if;
         end Name_Less;

         function Field_Less (Left : Item_Snapshot; Right : Item_Snapshot) return Boolean is
            Forward_Order : Boolean := False;
            Reverse_Order : Boolean := False;
         begin
            case Snapshot.Sort_Field is
               when Files.Model.Sort_Name =>
                  Forward_Order := Name_Less (Left => Left, Right => Right);
                  Reverse_Order := Name_Less (Left => Right, Right => Left);
               when Files.Model.Sort_Size =>
                  if Left.Size_Available /= Right.Size_Available then
                     return Left.Size_Available;
                  elsif Left.Size /= Right.Size then
                     Forward_Order := Left.Size < Right.Size;
                     Reverse_Order := Right.Size < Left.Size;
                  end if;
               when Files.Model.Sort_Type =>
                  declare
                     Left_Type       : constant String := To_String (Left.Filetype);
                     Right_Type      : constant String := To_String (Right.Filetype);
                     Left_Lowercase  : constant String := Files.Types.To_Lower (Left_Type);
                     Right_Lowercase : constant String := Files.Types.To_Lower (Right_Type);
                  begin
                     if Left_Lowercase /= Right_Lowercase then
                        Forward_Order := Left_Lowercase < Right_Lowercase;
                        Reverse_Order := Right_Lowercase < Left_Lowercase;
                     elsif Left_Type /= Right_Type then
                        Forward_Order := Left_Type < Right_Type;
                        Reverse_Order := Right_Type < Left_Type;
                     end if;
                  end;
               when Files.Model.Sort_Created =>
                  if Left.Creation_Available /= Right.Creation_Available then
                     return Left.Creation_Available;
                  elsif Left.Creation_Time /= Right.Creation_Time then
                     Forward_Order := Left.Creation_Time < Right.Creation_Time;
                     Reverse_Order := Right.Creation_Time < Left.Creation_Time;
                  end if;
               when Files.Model.Sort_Changed =>
                  if Left.Modified_Available /= Right.Modified_Available then
                     return Left.Modified_Available;
                  elsif Left.Modified_Time /= Right.Modified_Time then
                     Forward_Order := Left.Modified_Time < Right.Modified_Time;
                     Reverse_Order := Right.Modified_Time < Left.Modified_Time;
                  end if;
            end case;

            if Snapshot.Sort_Field /= Files.Model.Sort_Name
              and then not Forward_Order
              and then not Reverse_Order
            then
               return Name_Less (Left, Right);
            elsif Snapshot.Sort_Ascending then
               return Forward_Order;
            else
               return Reverse_Order;
            end if;
         end Field_Less;

         function Less (Left : Item_Snapshot; Right : Item_Snapshot) return Boolean is
         begin
            return Field_Less (Left, Right);
         end Less;

         package Sorting is new Item_Snapshot_Vectors.Generic_Sorting ("<" => Less);
      begin
         Sorting.Sort (Snapshot.Items);
      end;

      --  Grouping composes with the sort: the sorted items are partitioned into
      --  fixed-order bands, each introduced by a non-selectable header row. The
      --  header carries Visible_Index zero so hit-testing never selects it, and
      --  items keep their sorted order within a band.
      if Snapshot.View_Mode = Files.Types.Details
        and then Snapshot.Group_By /= Files.Types.No_Grouping
        and then not Snapshot.Items.Is_Empty
      then
         declare
            function Starts_With (Text : String; Prefix : String) return Boolean is
              (Text'Length >= Prefix'Length
               and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

            function Type_Band (Item : Item_Snapshot) return Positive is
               Mime : constant String := Files.Types.To_Lower (To_String (Item.Filetype));
            begin
               if Item.Kind = Files.Types.Directory_Item then
                  return 1;
               elsif Starts_With (Mime, "image/") then
                  return 2;
               elsif Starts_With (Mime, "audio/") then
                  return 3;
               elsif Starts_With (Mime, "video/") then
                  return 4;
               elsif Starts_With (Mime, "text/")
                 or else Mime = "application/pdf"
                 or else Starts_With (Mime, "application/json")
                 or else Starts_With (Mime, "application/xml")
                 or else Starts_With (Mime, "application/vnd.")
               then
                  return 5;
               elsif Mime = "application/zip"
                 or else Starts_With (Mime, "application/x-tar")
                 or else Starts_With (Mime, "application/gzip")
                 or else Starts_With (Mime, "application/x-7z")
                 or else Starts_With (Mime, "application/x-rar")
               then
                  return 6;
               else
                  return 7;
               end if;
            end Type_Band;

            function Modified_Band (Item : Item_Snapshot) return Positive is
               Now   : constant Ada.Calendar.Time := Ada.Calendar.Clock;
               Today : constant Ada.Calendar.Time := Day_Start (Now);
            begin
               if not Item.Modified_Available then
                  return 4;
               elsif Day_Start (Item.Modified_Time) = Today then
                  return 1;
               elsif Item.Modified_Time > Today - 6.0 * 86_400.0 then
                  return 2;
               else
                  return 3;
               end if;
            end Modified_Band;

            function Size_Band (Item : Item_Snapshot) return Positive is
            begin
               if not Item.Size_Available then
                  return 5;
               elsif Item.Size <= 0 then
                  return 1;
               elsif Item.Size < 1024 * 1024 then
                  return 2;
               elsif Item.Size < 1024 * 1024 * 1024 then
                  return 3;
               else
                  return 4;
               end if;
            end Size_Band;

            --  Color-label bands in canonical order: Red .. Gray (bands 1 .. 7,
            --  mirroring Files.Types.Real_Color_Label) then unlabeled (band 8).
            function Label_Band (Item : Item_Snapshot) return Positive is
            begin
               if Item.Label = Files.Types.No_Label then
                  return 8;
               else
                  return Files.Types.Color_Label'Pos (Item.Label);
               end if;
            end Label_Band;

            function Band_Count return Positive is
            begin
               case Snapshot.Group_By is
                  when Files.Types.Group_By_Type =>
                     return 7;
                  when Files.Types.Group_By_Modified =>
                     return 4;
                  when Files.Types.Group_By_Size =>
                     return 5;
                  when Files.Types.Group_By_Label =>
                     return 8;
                  when Files.Types.No_Grouping =>
                     return 1;
               end case;
            end Band_Count;

            function Band_Of (Item : Item_Snapshot) return Positive is
            begin
               case Snapshot.Group_By is
                  when Files.Types.Group_By_Type =>
                     return Type_Band (Item);
                  when Files.Types.Group_By_Modified =>
                     return Modified_Band (Item);
                  when Files.Types.Group_By_Size =>
                     return Size_Band (Item);
                  when Files.Types.Group_By_Label =>
                     return Label_Band (Item);
                  when Files.Types.No_Grouping =>
                     return 1;
               end case;
            end Band_Of;

            function Band_Label (Band : Positive) return String is
            begin
               case Snapshot.Group_By is
                  when Files.Types.Group_By_Type =>
                     case Band is
                        when 1 =>
                           return "details.group.folders";
                        when 2 =>
                           return "details.group.images";
                        when 3 =>
                           return "details.group.audio";
                        when 4 =>
                           return "details.group.video";
                        when 5 =>
                           return "details.group.documents";
                        when 6 =>
                           return "details.group.archives";
                        when others =>
                           return "details.group.other";
                     end case;
                  when Files.Types.Group_By_Modified =>
                     case Band is
                        when 1 =>
                           return "details.group.today";
                        when 2 =>
                           return "details.group.this_week";
                        when 3 =>
                           return "details.group.earlier";
                        when others =>
                           return "details.group.unknown_date";
                     end case;
                  when Files.Types.Group_By_Size =>
                     case Band is
                        when 1 =>
                           return "details.group.size_empty";
                        when 2 =>
                           return "details.group.size_small";
                        when 3 =>
                           return "details.group.size_medium";
                        when 4 =>
                           return "details.group.size_large";
                        when others =>
                           return "details.group.size_unknown";
                     end case;
                  when Files.Types.Group_By_Label =>
                     case Band is
                        when 1 =>
                           return "label.color.red";
                        when 2 =>
                           return "label.color.orange";
                        when 3 =>
                           return "label.color.yellow";
                        when 4 =>
                           return "label.color.green";
                        when 5 =>
                           return "label.color.blue";
                        when 6 =>
                           return "label.color.purple";
                        when 7 =>
                           return "label.color.gray";
                        when others =>
                           return "details.group.unlabeled";
                     end case;
                  when Files.Types.No_Grouping =>
                     return "";
               end case;
            end Band_Label;

            Grouped : Item_Snapshot_Vectors.Vector;
         begin
            for Band in 1 .. Band_Count loop
               declare
                  Emitted_Header : Boolean := False;
               begin
                  for Item of Snapshot.Items loop
                     if Band_Of (Item) = Band then
                        if not Emitted_Header then
                           Grouped.Append
                             (Item_Snapshot'
                                (Is_Group_Header => True,
                                 Group_Label     =>
                                   To_Unbounded_String (Files.Localization.Text (Band_Label (Band))),
                                 Visible_Index   => 0,
                                 others          => <>));
                           Emitted_Header := True;
                        end if;
                        Grouped.Append (Item);
                     end if;
                  end loop;
               end;
            end loop;
            Snapshot.Items := Grouped;
         end;
      end if;

      --  Combined selection total: every selected file's size plus the recursive
      --  size of each selected folder. Computed for any selection (not only when
      --  the info pane is open) so the bottom bar's total counts folder contents.
      --  Folders not yet measured mark the total pending (still growing).
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
            for Item of Files.Model.Selected_Items (Model) loop
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
            Items : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);

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
              Files.Model.Current_Path (Model) = Files.File_System.Trash_Files_Directory;
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
               for Item of Items loop
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
