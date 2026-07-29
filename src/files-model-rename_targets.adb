separate (Files.Model)
   function Rename_Targets
     (Model : Window_Model)
      return Rename_Target_Vectors.Vector
   is
      Result : Rename_Target_Vectors.Vector;
   begin
      for Field of Model.Rename_Fields loop
         if Field.Item_Index in 1 .. Natural (Model.Items.Last_Index) then
            declare
               Item : constant Files.File_System.Directory_Item :=
                 Model.Items.Element (Positive (Field.Item_Index));
            begin
               Result.Append
                 (Rename_Target'
                    (Item_Index    => Field.Item_Index,
                     Old_Full_Path => Item.Full_Path,
                     Old_Name      => Item.Name,
                     New_Name      => Field.Value));
            end;
         end if;
      end loop;

      return Result;
   end Rename_Targets;
