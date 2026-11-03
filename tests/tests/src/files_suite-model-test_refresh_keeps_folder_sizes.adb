with Ada.Calendar;
separate (Files_Suite.Model)
   --  A watched folder reloads every two seconds while a file in it grows; a
   --  refresh used to drop every measured folder size (and stop the helper
   --  measuring the rest), so a big selected folder never got a size.
   procedure Test_Refresh_Keeps_Folder_Sizes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model;
      Items : Files.Items.Item_Vectors.Vector;
      Big   : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "big");
      Small : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "small");
      Sized : constant Files.File_System.Directory_Size_Result :=
        (Available => True, Total_Bytes => 42, File_Count => 1, Item_Count => 1, Capped => False);
      type Name_Array is array (Positive range <>) of Unbounded_String;
   begin
      for Name of Name_Array'(1 => To_Unbounded_String ("big"), 2 => To_Unbounded_String ("small")) loop
         declare
            Item : Files.Items.Directory_Item :=
              Files.File_System.Make_Item
                (Files_Suite.Support.Root, To_String (Name), Files.Types.Directory_Item, "inode/directory");
         begin
            Item.Modified_Time := Ada.Calendar.Time_Of (2026, 1, 1);
            Item.Modified_Available := True;
            Items.Append (Item);
         end;
      end loop;
      Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Testing.Set_Folder_Size (Model, Big, Sized);
      Files.Model.Testing.Set_Folder_Size (Model, Small, Sized);

      Files.Model.Replace_Items (Model, Items);
      Assert (Files.Model.Folder_Size_Cached_For (Model, Big), "an unchanged folder keeps its size");
      Assert (Files.Model.Folder_Size_Cached_For (Model, Small), "so does the other");

      --  Something in small changed: its own time moved, it is measured again.
      Items (2).Modified_Time := Items (2).Modified_Time + 60.0;
      Files.Model.Replace_Items (Model, Items);
      Assert (Files.Model.Folder_Size_Cached_For (Model, Big), "the unchanged folder still keeps its size");
      Assert (not Files.Model.Folder_Size_Cached_For (Model, Small), "a changed folder is measured again");
   end Test_Refresh_Keeps_Folder_Sizes;
