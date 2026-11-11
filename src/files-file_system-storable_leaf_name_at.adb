separate (Files.File_System)
function Storable_Leaf_Name_At
  (Name      : String;
   Directory : String)
   return Boolean
is
begin
   if Hostkit.Fs.Uses_Dos_Filename_Rules (Directory) then
      --  A name Windows already holds may carry a lone UTF-16 surrogate,
      --  which hostkit reads as its three WTF-8 bytes (ED A0..BF xx): not
      --  UTF-8, but storable there. Each such triple stands for one ordinary
      --  character while the rest of the name is checked.
      declare
         Checked : String (1 .. Name'Length);
         Last    : Natural := 0;
         Index   : Positive := Name'First;
      begin
         while Index <= Name'Last loop
            if Index + 2 <= Name'Last
              and then Character'Pos (Name (Index)) = 16#ED#
              and then Character'Pos (Name (Index + 1)) in 16#A0# .. 16#BF#
              and then Character'Pos (Name (Index + 2)) in 16#80# .. 16#BF#
            then
               Last := Last + 1;
               Checked (Last) := '_';
               Index := Index + 3;
            else
               Last := Last + 1;
               Checked (Last) := Name (Index);
               Index := Index + 1;
            end if;
         end loop;
         return Valid_Leaf_Name (Checked (1 .. Last), Windows_Rules);
      end;
   end if;
   return Name /= "" and then Name /= "." and then Name /= ".."
     and then (for all C of Name => C /= '/' and then C /= ASCII.NUL);
end Storable_Leaf_Name_At;
