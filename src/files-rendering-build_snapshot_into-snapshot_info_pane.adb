separate (Files.Rendering.Build_Snapshot_Into)
   --  The info pane's rows: one per selected item, up to Max_Info_Items, and
   --  whether the single selected item's permissions and owner can be edited.
   procedure Snapshot_Info_Pane is
      --  The info pane shows at most Max_Info_Items: only those are copied.
      Items : constant Files.Items.Item_Vectors.Vector :=
        Files.Model.Selection.Selected_Items (Model, Limit => Max_Info_Items);

      function Build_Info
        (Item : Files.Items.Directory_Item)
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
           and then Files.Model.Folder_Sizes.Cached_For (Model, To_String (Item.Full_Path))
         then
            declare
               Measured : constant Files.File_System.Directory_Size_Result :=
                 Files.Model.Folder_Sizes.Value (Model, To_String (Item.Full_Path));
            begin
               Info.Folder_Size_Available := Measured.Available;
               Info.Folder_Size_Bytes     := Measured.Total_Bytes;
               Info.Folder_File_Count      := Measured.File_Count;
               Info.Folder_Item_Count      := Measured.Item_Count;
               Info.Folder_Size_Capped     := Measured.Capped;
            end;
         end if;

         --  Owner/group names as the window layer sampled them into the
         --  model; an id not sampled yet shows as its number.
         if Item.Ownership_Available then
            Info.Owner_Name :=
              To_Unbounded_String
                (Files.Model.Status_Samples.Account_Name (Model, Files.Model.User_Account, Item.Owner_Id));
            Info.Group_Name :=
              To_Unbounded_String
                (Files.Model.Status_Samples.Account_Name (Model, Files.Model.Group_Account, Item.Group_Id));
         end if;

         return Info;
      end Build_Info;

      Single_Item : constant Files.Items.Directory_Item :=
        Files.Model.Selection.Selected_Item (Model);
      In_Trash    : constant Boolean := Files.Model.Current_Is_Trash (Model);
   begin
      Snapshot.Permissions_Editable :=
        Files.Model.Selection.Selected_Count (Model) = 1
        and then not In_Trash
        and then Files.File_System.Supports_Permissions
        and then Single_Item.Mode_Available;

      Snapshot.Ownership_Editable :=
        Files.Model.Selection.Selected_Count (Model) = 1
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
   end Snapshot_Info_Pane;
