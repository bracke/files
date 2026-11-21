separate (Files.Rendering)
function Item_Now
  (Drawn : View_Snapshot;
   Index : Natural;
   Model : Files.Model.Window_Model)
   return Natural is
begin
   if Index = 0 then
      return 0;
   end if;
   for Item of Drawn.Items loop
      if Item.Visible_Index = Index then
         return Files.Model.Visible_Index_Of (Model, To_String (Item.Full_Path));
      end if;
   end loop;
   return 0;
end Item_Now;
