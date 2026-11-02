with Files.Items;
separate (Files.Model)
function Visible_Rows
  (Model : Window_Model)
   return Visible_Row_Vectors.Vector
is
   Rows : Visible_Row_Vectors.Vector;

   procedure Add (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean) is
   begin
      Rows.Append (Visible_Row'(Item => Item, Selected => Selected, Item_Index => Item_Index));
   end Add;
begin
   Rows.Reserve_Capacity (Ada.Containers."+" (Model.Items.Length, 1));
   For_Each_Visible_Row (Model, Add'Access);
   return Rows;
end Visible_Rows;
