with Files.Model.Recent;
separate (Files.Job_Drivers.Operation.Advance)
procedure Note_Moves is
begin
   for Move of Done.Moves loop
      case Move.Kind is
         when Files.Types.Removed =>
            Files.Model.Recent.Note_Path_Removed (Model, To_String (Move.From));
         when Files.Types.Moved =>
            Files.Model.Recent.Note_Path_Move (Model, To_String (Move.From), To_String (Move.To));
      end case;
   end loop;
end Note_Moves;
