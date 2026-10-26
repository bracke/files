separate (Files_Suite.Operations)
   --  Items with one name (search results from several folders) come out in
   --  one order whatever order they went in: the sort is not stable, so its
   --  comparison must be a total order.
   procedure Test_Sort_Is_Total_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Forward, Backward : Files.File_System.Item_Vectors.Vector;

      function Item (Folder : String) return Files.File_System.Directory_Item is
         Result : Files.File_System.Directory_Item;
      begin
         Result.Name := To_Unbounded_String ("README.md");
         Result.Full_Path := To_Unbounded_String ("/" & Folder & "/README.md");
         Result.Kind := Files.Types.Regular_File_Item;
         return Result;
      end Item;
   begin
      for Index in 1 .. 40 loop
         Forward.Append (Item ("f" & Index'Image));
      end loop;
      for Index in reverse 1 .. 40 loop
         Backward.Append (Item ("f" & Index'Image));
      end loop;
      for Field in Files.Types.Sort_Field loop
         for Ascending in Boolean loop
            declare
               A : Files.File_System.Item_Vectors.Vector := Forward;
               B : Files.File_System.Item_Vectors.Vector := Backward;
            begin
               Files.File_System.Sort_Items (A, Field, Ascending);
               Files.File_System.Sort_Items (B, Field, Ascending);
               for Index in 1 .. 40 loop
                  Assert (A (Index).Full_Path = B (Index).Full_Path,
                          "equal names sort the same whatever their input order: "
                          & Files.Types.Sort_Field'Image (Field));
               end loop;
            end;
         end loop;
      end loop;
   end Test_Sort_Is_Total_Order;
