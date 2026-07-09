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
      is
         function Upper_Extension (Extension : String) return String is
            Result : String (Extension'Range);
         begin
            for Index in Extension'Range loop
               Result (Index) := Ada.Characters.Handling.To_Upper (Extension (Index));
            end loop;

            return Result;
         end Upper_Extension;

         function Extension_File_Label return UString is
            Extension : constant String := Files.File_Types.Extension_Of (To_String (Item.Name));
         begin
            if Extension = "" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.file"));
            end if;

            return
              To_Unbounded_String (Upper_Extension (Extension));
         end Extension_File_Label;
      begin
         case Item.Kind is
            when Files.Types.Directory_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.directory"));
            when Files.Types.Symlink_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.symlink"));
            when Files.Types.Executable_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.executable"));
            when Files.Types.Regular_File_Item =>
               if To_String (Item.Filetype) = "text/plain" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.text"));
               elsif To_String (Item.Filetype) = "text/markdown" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.markdown"));
               elsif To_String (Item.Filetype) = "text/x-ada" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.source.ada"));
               elsif To_String (Item.Filetype) = "application/json" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.source.json"));
               elsif To_String (Item.Filetype) = "application/xml" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.source.xml"));
               elsif To_String (Item.Filetype) = "image/png" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.image.png"));
               elsif To_String (Item.Filetype) = "image/jpeg" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.image.jpeg"));
               elsif To_String (Item.Filetype) = "application/pdf" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.document.pdf"));
               elsif To_String (Item.Filetype) =
                 "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.document.word"));
               elsif To_String (Item.Filetype) =
                 "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.document.spreadsheet"));
               elsif To_String (Item.Filetype) = "application/zip"
                 or else To_String (Item.Filetype) = "application/x-tar"
                 or else To_String (Item.Filetype) = "application/gzip-tar"
                 or else To_String (Item.Filetype) = "application/gzip"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.archive"));
               elsif To_String (Item.Filetype) = "audio/mpeg"
                 or else To_String (Item.Filetype) = "audio/wav"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.audio"));
               elsif To_String (Item.Filetype) = "video/mp4" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.video"));
               end if;

               return Extension_File_Label;
            when Files.Types.Other_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.other"));
            when Files.Types.Unknown_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.unknown"));
         end case;

      end Filetype_Detail;

      function Filetype_Extra
        (Item : Files.File_System.Directory_Item)
         return UString
      is
         Type_Name : constant String := To_String (Item.Filetype);

         function Token_Detail (Token : String) return UString is
            Separator : constant Natural := Ada.Strings.Fixed.Index (Token, "|");

            function Prefix_Value
              (Prefix_Key : String;
               Value      : String;
               Suffix_Key : String)
               return String
            is
               Prefix : constant String :=
                 Ada.Strings.Fixed.Trim (Files.Localization.Text (Prefix_Key), Ada.Strings.Right);
               Suffix : constant String :=
                 Ada.Strings.Fixed.Trim (Files.Localization.Text (Suffix_Key), Ada.Strings.Left);
            begin
               if Suffix'Length > 0
                 and then Ada.Characters.Handling.Is_Alphanumeric (Suffix (Suffix'First))
               then
                  return Prefix & " " & Value & " " & Suffix;
               else
                  return Prefix & " " & Value & Suffix;
               end if;
            end Prefix_Value;

            function Prefix_Localized_Value
              (Prefix_Key : String;
               Value_Key  : String;
               Suffix_Key : String)
               return String
            is
            begin
               return Prefix_Value (Prefix_Key, Files.Localization.Text (Value_Key), Suffix_Key);
            end Prefix_Localized_Value;

            function Lines_And_Encoding
              (Lines_Prefix_Key : String;
               Lines            : String;
               Lines_Suffix_Key : String;
               Encoding         : String)
               return String
            is
            begin
               return
                 Prefix_Value (Lines_Prefix_Key, Lines, Lines_Suffix_Key)
                 & " "
                 & Prefix_Localized_Value
                   ("info.extra.encoding.prefix",
                    "info.extra.encoding." & Encoding,
                    "info.extra.encoding.suffix");
            end Lines_And_Encoding;
         begin
            if Separator <= Token'First or else Separator >= Token'Last then
               return Null_Unbounded_String;
            end if;

            declare
               Key   : constant String := Token (Token'First .. Separator - 1);
               Value : constant String := Token (Separator + 1 .. Token'Last);
               Second : constant Natural := Ada.Strings.Fixed.Index (Value, "|");
            begin
               if Key = "executable.format" then
                  return
                    To_Unbounded_String
                      (Prefix_Localized_Value
                         ("info.extra.executable.format.prefix",
                          "info.extra.executable.format." & Value,
                          "info.extra.executable.format.suffix"));
               elsif Key = "directory.count" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.directory.count.prefix", Value, "info.extra.directory.count.suffix"));
               elsif Key = "text.lines" then
                  return
                    To_Unbounded_String
                      (Prefix_Value ("info.extra.text.lines.prefix", Value, "info.extra.text.lines.suffix"));
               elsif Key = "text.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Lines_And_Encoding
                            ("info.extra.text.lines.prefix",
                             Lines,
                             "info.extra.text.lines.suffix",
                             Encoding));
                  end;
               elsif Key = "markdown.lines" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.markdown.lines.prefix", Value, "info.extra.markdown.lines.suffix"));
               elsif Key = "markdown.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Lines_And_Encoding
                            ("info.extra.markdown.lines.prefix",
                             Lines,
                             "info.extra.markdown.lines.suffix",
                             Encoding));
                  end;
               elsif Key = "image.dimensions" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.image.dimensions.prefix", Value, "info.extra.image.dimensions.suffix"));
               elsif Key = "symlink.target" then
                  return
                    To_Unbounded_String
                      (Prefix_Value ("info.extra.symlink.target.prefix", Value, "info.extra.symlink.target.suffix"));
               elsif Key = "document.kind" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.document." & Value));
               elsif Key = "document.pdf.pages" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.document.pdf.pages.prefix", Value, "info.extra.document.pdf.pages.suffix"));
               elsif Key = "archive.format" then
                  return
                    To_Unbounded_String
                      (Prefix_Localized_Value
                         ("info.extra.archive.format.prefix",
                          "info.extra.archive.format." & Value,
                          "info.extra.archive.format.suffix"));
               elsif Key = "archive.zip.entries" or else Key = "archive.gzip-tar.entries" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.archive.entries.prefix", Value, "info.extra.archive.entries.suffix"));
               elsif Key = "office.docx.entries" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.office.docx.prefix", Value, "info.extra.office.entries.suffix"));
               elsif Key = "office.xlsx.entries" then
                  return
                    To_Unbounded_String
                      (Prefix_Value
                         ("info.extra.office.xlsx.prefix", Value, "info.extra.office.entries.suffix"));
               elsif Key = "media.kind" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.media." & Value));
               elsif Key = "source.ada.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Lines_And_Encoding
                            ("info.extra.source.ada.prefix",
                             Lines,
                             "info.extra.source.lines.suffix",
                             Encoding));
                  end;
               elsif Key = "source.json.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Lines_And_Encoding
                            ("info.extra.source.json.prefix",
                             Lines,
                             "info.extra.source.lines.suffix",
                             Encoding));
                  end;
               elsif Key = "source.xml.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Lines_And_Encoding
                            ("info.extra.source.xml.prefix",
                             Lines,
                             "info.extra.source.lines.suffix",
                             Encoding));
                  end;
               end if;
            end;

            return Null_Unbounded_String;
         end Token_Detail;

         function Extension_Detail
           (Name : String)
            return String
         is
            Extension : constant String := Files.File_Types.Extension_Of (Name);
         begin
            if Extension = "" then
               return Files.Localization.Text ("info.extra.file");
            end if;

            return
              Files.Localization.Text ("info.extra.extension.prefix")
              & Extension
              & Files.Localization.Text ("info.extra.extension.suffix");
         end Extension_Detail;
      begin
         if Length (Item.Filetype_Extra) > 0 then
            declare
               Detail : constant UString := Token_Detail (To_String (Item.Filetype_Extra));
            begin
               if Length (Detail) > 0 then
                  return Detail;
               end if;
            end;
         end if;

         case Item.Kind is
            when Files.Types.Directory_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.directory"));
            when Files.Types.Symlink_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.symlink"));
            when Files.Types.Executable_Item =>
               if Item.Size_Available then
                  declare
                     Prefix : constant String :=
                       Ada.Strings.Fixed.Trim
                         (Files.Localization.Text ("info.extra.executable.size.prefix"), Ada.Strings.Right);
                     Suffix : constant String :=
                       Ada.Strings.Fixed.Trim
                         (Files.Localization.Text ("info.extra.executable.size.suffix"), Ada.Strings.Left);
                     Size_Text : constant String :=
                       Ada.Strings.Fixed.Trim (Long_Long_Integer'Image (Item.Size), Ada.Strings.Both);
                  begin
                     if Suffix'Length > 0
                       and then Ada.Characters.Handling.Is_Alphanumeric (Suffix (Suffix'First))
                     then
                        return To_Unbounded_String (Prefix & " " & Size_Text & " " & Suffix);
                     else
                        return To_Unbounded_String (Prefix & " " & Size_Text & Suffix);
                     end if;
                  end;
               else
                  return
                    To_Unbounded_String (Files.Localization.Text ("info.extra.executable"));
               end if;
            when Files.Types.Other_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.other"));
            when Files.Types.Unknown_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.unknown"));
            when Files.Types.Regular_File_Item =>
               if Type_Name = "text/plain" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.text"));
               elsif Type_Name = "text/markdown" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.markdown"));
               elsif Type_Name'Length >= 6
                 and then Type_Name (Type_Name'First .. Type_Name'First + 5) = "image/"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.image"));
               elsif Type_Name = "application/octet-stream" then
                  return To_Unbounded_String (Extension_Detail (To_String (Item.Name)));
               end if;
         end case;

         return To_Unbounded_String (Extension_Detail (To_String (Item.Name)));
      end Filetype_Extra;

      function Root_Display_Label
        (Path  : String;
         Label : String)
         return String is
      begin
         declare
            Separator : constant Natural := Ada.Strings.Fixed.Index (Label, "|");
         begin
            if Separator > Label'First then
               declare
                  Key       : constant String := Label (Label'First .. Separator - 1);
                  Tail      : constant String := Label (Separator + 1 .. Label'Last);
                  Second    : constant Natural := Ada.Strings.Fixed.Index (Tail, "|");
                  Value_End : constant Natural :=
                    (if Second = 0 then Tail'Last else Second - 1);
                  Value     : constant String := Tail (Tail'First .. Value_End);
               begin
                  if Second = 0 then
                     return
                       Files.Localization.Text (Key & ".prefix")
                       & Value
                       & Files.Localization.Text (Key & ".suffix");
                  else
                     declare
                        Detail : constant String := Tail (Second + 1 .. Tail'Last);
                     begin
                        return
                          Files.Localization.Text (Key & ".prefix")
                          & Value
                          & Files.Localization.Text ("root.detail.prefix")
                          & Detail
                          & Files.Localization.Text ("root.detail.suffix")
                          & Files.Localization.Text (Key & ".suffix");
                     end;
                  end if;
               end;
            end if;
         end;

         if Label'Length >= 5
           and then Label (Label'First .. Label'First + 4) = "root."
         then
            return Files.Localization.Text (Label);
         elsif Label /= "" then
            return Label;
         else
            return Path;
         end if;
      end Root_Display_Label;
   begin
      Snapshot.Current_Path := To_Unbounded_String (Files.Model.Current_Path (Model));
      Snapshot.Current_Path_Is_Favorite :=
        Files.Settings.Is_Favorite (Settings, Files.Model.Current_Path (Model));
      Snapshot.In_Recent_View := Files.Model.In_Recent_View (Model);
      Snapshot.View_Mode := Files.Model.View_Mode_Of (Model);
      Snapshot.Sort_Field := Files.Model.Sort_Field_Of (Model);
      Snapshot.Sort_Ascending := Files.Model.Sort_Is_Ascending (Model);
      Snapshot.Sort_Menu_Open := Files.Model.Sort_Menu_Is_Open (Model);
      Snapshot.Show_Extensions := Settings.Show_File_Extensions;
      Snapshot.Detail_Columns_Visible := Settings.Column_Visible;
      Snapshot.Detail_Column_Widths := Settings.Column_Widths;
      Snapshot.Detail_Column_Order := Settings.Column_Order;
      Snapshot.Group_By := Settings.Group_By;
      Snapshot.Item_Count := Files.Model.Item_Count (Model);
      Snapshot.Visible_Count := Files.Model.Visible_Count (Model);
      Snapshot.Hidden_Count := Files.Model.Hidden_Item_Count (Model);
      Snapshot.Selected_Count := Files.Model.Selected_Count (Model);
      declare
         --  Free-space is derived per snapshot from the current directory's
         --  filesystem, mirroring how the hidden count is queried above. The
         --  platform accessor reports Available = False when the volume cannot
         --  be measured (non-Linux stubs, unreadable paths), so a bogus zero is
         --  never shown as a known value.
         Capacity : constant Files.Platform.Metadata.Volume_Capacity :=
           Files.Platform.Metadata.Volume_Capacity_Of (Files.Model.Current_Path (Model));
      begin
         Snapshot.Free_Space_Known := Capacity.Available;
         Snapshot.Free_Space_Bytes := Capacity.Free_Bytes;
         Snapshot.Total_Space_Bytes := Capacity.Capacity_Bytes;
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
            --  Reuse the item's already-decoded thumbnail pixels for the image
            --  preview; the renderer scales them to fit the panel.
            if Content.Kind = Files.Quick_Look.Image_Content
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
         Cut_Paths  : constant Files.Types.String_Vectors.Vector :=
           (if Cut_Active then Files.Model.Clipboard_Paths (Model)
            else Files.Types.String_Vectors.Empty_Vector);

         function Is_Cut_Pending (Full_Path : Ada.Strings.Unbounded.Unbounded_String)
           return Boolean is
         begin
            if not Cut_Active then
               return False;
            end if;
            for Path of Cut_Paths loop
               if Path = Full_Path then
                  return True;
               end if;
            end loop;
            return False;
         end Is_Cut_Pending;
      begin
         for Index in 1 .. Files.Model.Visible_Count (Model) loop
            declare
               Item : constant Files.File_System.Directory_Item := Files.Model.Visible_Item (Model, Index);
               Rename_On     : Boolean;
               Rename_Value  : Ada.Strings.Unbounded.Unbounded_String;
               Rename_Cursor : Natural;
            begin
               Files.Model.Rename_State_For_Visible
                 (Model, Index, Rename_On, Rename_Value, Rename_Cursor);
               Snapshot.Items.Append
                 (Item_Snapshot'
                    (Name               => Item.Name,
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
                     Thumbnail_Pixels    => Item.Thumbnail_Pixels,
                     Metadata_Error     => Item.Metadata_Error,
                     Error_Key          => Item.Error_Key,
                     Selected           => Files.Model.Is_Selected (Model, Index),
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
            Left_Text       : constant String := To_String (Left.Name);
            Right_Text      : constant String := To_String (Right.Name);
            Left_Lowercase  : constant String := Files.Types.To_Lower (Left_Text);
            Right_Lowercase : constant String := Files.Types.To_Lower (Right_Text);
         begin
            if Left_Lowercase /= Right_Lowercase then
               return Left_Lowercase < Right_Lowercase;
            else
               return Left_Text < Right_Text;
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
                       Files.Model.Folder_Size_Value (Model);
                  begin
                     Info.Folder_Size_Available := Measured.Available;
                     Info.Folder_Size_Bytes     := Measured.Total_Bytes;
                     Info.Folder_File_Count      := Measured.File_Count;
                     Info.Folder_Item_Count      := Measured.Item_Count;
                     Info.Folder_Size_Capped     := Measured.Capped;
                  end;
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
