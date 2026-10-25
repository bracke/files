separate (Files.Model)
procedure Take_Retired_History
  (Model         : in out Window_Model;
   Discarded     : out Files.Types.String_Vectors.Vector;
   Released      : out Files.Types.String_Vectors.Vector;
   Journal_Dirty : out Boolean) is
begin
   Discarded := Model.Retired_Discards;
   Released := Model.Retired_Releases;
   Journal_Dirty := Model.History_Journal_Dirty;
   Model.Retired_Discards.Clear;
   Model.Retired_Releases.Clear;
   Model.History_Journal_Dirty := False;
end Take_Retired_History;
