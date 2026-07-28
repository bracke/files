separate (Files.Rendering)
   function Calculate_Context_Menu_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Context_Menu_Layout
   is
      Result : Context_Menu_Layout;
      Next   : Natural := 0;

      --  Append a selectable command row.
      procedure Add_Command (Command : Files.Commands.Command_Id) is
      begin
         Next := Next + 1;
         Result.Commands (Next) := Command;
         Result.Row_Kinds (Next) := Command_Row;
      end Add_Command;

      --  Append a non-selectable divider row between two command groups.
      procedure Add_Separator is
      begin
         Next := Next + 1;
         Result.Commands (Next) := Files.Commands.No_Command;
         Result.Row_Kinds (Next) := Separator_Row;
      end Add_Separator;
   begin
      if not Snapshot.Context_Menu_Open then
         return Result;
      end if;

      case Snapshot.Context_Menu_Target is
         when Files.Model.Context_Menu_Item =>
            --  Group 1: open actions, including revealing a search result in its
            --  containing folder.
            Add_Command (Files.Commands.Open_Selected_Items_Command);
            Add_Command (Files.Commands.Open_With_Command);
            Add_Command (Files.Commands.Open_Containing_Folder_Command);
            Add_Separator;
            --  Group 2: favorite the current selection and set its color label
            --  (tagging verbs grouped together).
            Add_Command (Files.Commands.Toggle_Favorite_Command);
            Add_Command (Files.Commands.Set_Color_Label_Command);
            Add_Separator;
            --  Group 3: clipboard / duplication, including the copy-to and
            --  move-to destination pickers next to the plain clipboard verbs.
            Add_Command (Files.Commands.Copy_Selected_Items_Command);
            Add_Command (Files.Commands.Cut_Selected_Items_Command);
            Add_Command (Files.Commands.Copy_Path_Command);
            Add_Command (Files.Commands.Copy_To_Command);
            Add_Command (Files.Commands.Move_To_Command);
            Add_Command (Files.Commands.Duplicate_Selected_Command);
            Add_Separator;
            --  Group 4: archive actions.
            Add_Command (Files.Commands.Compress_Zip_Command);
            Add_Command (Files.Commands.Compress_7z_Command);
            Add_Command (Files.Commands.Extract_Archive_Command);
            Add_Separator;
            --  Group 5: link creation.
            Add_Command (Files.Commands.Create_Symlink_Command);
            Add_Command (Files.Commands.Create_Hardlink_Command);
            Add_Separator;
            --  Group 6: destructive / recovery actions.
            Add_Command (Files.Commands.Rename_Selected_Items_Command);
            Add_Command (Files.Commands.Delete_Selected_Items_Command);
            Add_Command (Files.Commands.Restore_From_Trash_Command);
            Result.Row_Count := Next;
         when Files.Model.Context_Menu_Empty =>
            Add_Command (Files.Commands.Create_File_Command);
            Add_Command (Files.Commands.New_Folder_Command);
            Add_Command (Files.Commands.Paste_Items_Command);
            Add_Separator;
            --  Background directory actions: open a terminal here and refresh.
            Add_Command (Files.Commands.Open_Terminal_Command);
            Add_Command (Files.Commands.Refresh_Directory_Command);
            Add_Separator;
            --  Trash-view action: permanently purge every trashed entry. Enabled
            --  only while the trash payload directory is shown and non-empty.
            Add_Command (Files.Commands.Empty_Trash_Command);
            --  Recent-view action: empty the recent list. Enabled only while the
            --  virtual recent view is shown and non-empty.
            Add_Command (Files.Commands.Clear_Recent_Command);
            Result.Row_Count := Next;
         when Files.Model.Context_Menu_Header =>
            --  Details-view column configuration: toggle each optional column,
            --  then cycle the grouping mode. Reuses the same layout/hit-test the
            --  item and empty-area menus draw with.
            Add_Command (Files.Commands.Toggle_Column_Modified_Command);
            Add_Command (Files.Commands.Toggle_Column_Size_Command);
            Add_Command (Files.Commands.Toggle_Column_Type_Command);
            Add_Command (Files.Commands.Toggle_Column_Created_Command);
            Add_Command (Files.Commands.Toggle_Column_Permissions_Command);
            Add_Separator;
            Add_Command (Files.Commands.Cycle_Group_By_Command);
            Result.Row_Count := Next;
         when Files.Model.Context_Menu_None =>
            return Result;
      end case;

      Result.Padding := 4;
      Result.Row_Height :=
        Saturating_Add (Line_Height, Saturating_Multiply (Result.Padding, 2));
      --  A separator is just a 1px divider line surrounded by the row padding,
      --  so it takes noticeably less vertical space than a command row.
      Result.Separator_Height :=
        Saturating_Add (1, Saturating_Multiply (Result.Padding, 2));

      --  Size the menu to the widest command label (using the same monospace
      --  cell metric and edge padding the renderer draws rows with) so labels
      --  are not truncated, then clamp to the available screen width.
      declare
         Cell_W    : constant Positive :=
           Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
         Edge_Pad  : constant Natural :=
           Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2);
         Max_Label : Natural := 0;
      begin
         for Row in 1 .. Result.Row_Count loop
            if Result.Row_Kinds (Row) = Command_Row then
               declare
                  Label : constant String :=
                    Files.Localization.Text
                      (Files.Commands.Name_Key (Result.Commands (Row)));
                  Label_W : constant Natural :=
                    Saturating_Multiply (Files.UTF8.Display_Units (Label), Cell_W);
               begin
                  Max_Label := Natural'Max (Max_Label, Label_W);
               end;
            end if;
         end loop;

         Result.Width :=
           Natural'Max
             (Natural'Max (Saturating_Multiply (Line_Height, 9), 180),
              Saturating_Add (Max_Label, Edge_Pad));

         if Width > 0 and then Result.Width > Width then
            Result.Width := Width;
         end if;
      end;

      declare
         Rows_Height : Natural := 0;
      begin
         for Row in 1 .. Result.Row_Count loop
            Rows_Height :=
              Saturating_Add
                (Rows_Height,
                 (if Result.Row_Kinds (Row) = Separator_Row
                  then Result.Separator_Height
                  else Result.Row_Height));
         end loop;
         Result.Height :=
           Saturating_Add
             (Rows_Height, Saturating_Multiply (Result.Padding, 2));
      end;

      --  Anchor to the cursor but keep the menu fully on-screen.
      Result.X :=
        (if Snapshot.Context_Menu_X + Result.Width > Width
         then (if Width > Result.Width then Width - Result.Width else 0)
         else Snapshot.Context_Menu_X);
      Result.Y :=
        (if Snapshot.Context_Menu_Y + Result.Height > Height
         then (if Height > Result.Height then Height - Result.Height else 0)
         else Snapshot.Context_Menu_Y);
      Result.Visible := Result.Width > 0 and then Result.Height > 0;

      return Result;
   end Calculate_Context_Menu_Layout;
