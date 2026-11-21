package body Files.Undo.History is

   function From_Paths (Action : Undo_Entry) return Files.Types.String_Vectors.Vector is
   begin
      return Paths : Files.Types.String_Vectors.Vector do
         for Item of Action.Items loop
            Paths.Append (Item.From);
         end loop;
      end return;
   end From_Paths;

   function Replaced_Trash (Action : Undo_Entry) return Files.Types.String_Vectors.Vector is
   begin
      return Paths : Files.Types.String_Vectors.Vector do
         for Original of Action.Replaced loop
            Paths.Append (Original.Trash);
         end loop;
      end return;
   end Replaced_Trash;

end Files.Undo.History;
