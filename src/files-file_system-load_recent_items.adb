with Files.Settings.Path_References;
separate (Files.File_System)
function Load_Recent_Items (Settings : Files.Settings.Settings_Model) return Item_Vectors.Vector is
   Items : Item_Vectors.Vector;
begin
   for Path of Files.Settings.Path_References.Recent_Paths (Settings) loop
      declare
         Loaded : constant Item_Load_Result := Load_Item (To_String (Path), Settings);
      begin
         if Loaded.Success then
            Items.Append (Loaded.Item);
         end if;
      end;
   end loop;
   return Items;
end Load_Recent_Items;
