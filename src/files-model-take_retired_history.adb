separate (Files.Model)
procedure Take_Retired_History
  (Model         : in out Window_Model;
   Discarded     : out Files.Types.String_Vectors.Vector;
   Released      : out Files.Types.String_Vectors.Vector;
   Journal_Dirty : out Boolean) is
begin
   Discarded := Model.History.Retired_Discards;
   Released := Model.History.Retired_Releases;
   Journal_Dirty := Model.History.Journal_Dirty;
   Model.History.Retired_Discards.Clear;
   Model.History.Retired_Releases.Clear;
   Model.History.Journal_Dirty := False;
end Take_Retired_History;
