separate (Files.Model)
function Is_Selected_Directory
  (Model : Window_Model;
   Path  : String)
   return Boolean is
   use type Files.Types.Item_Kind;
begin
   --  Read in place: every folder-size result asks this, and copying the
   --  selection for each made a large selection quadratic.
   for Index of Model.Selected_Item_Indexes loop
      if Index in Model.Items.First_Index .. Model.Items.Last_Index then
         declare
            Item : Files.Items.Directory_Item renames Model.Items (Index);
         begin
            if Item.Kind = Files.Types.Directory_Item
              and then To_String (Item.Full_Path) = Path
            then
               return True;
            end if;
         end;
      end if;
   end loop;
   return False;
end Is_Selected_Directory;
