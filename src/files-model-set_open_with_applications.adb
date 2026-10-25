separate (Files.Model)
procedure Set_Open_With_Applications
  (Model        : in out Window_Model;
   Applications : Files.Desktop_Applications.Application_Vectors.Vector) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Open_With_Applications_Value := Applications;
end Set_Open_With_Applications;
