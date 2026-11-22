separate (Files.File_System)
function Load_Directory
  (Path    : String;
   Classes : Files.File_Types.Classification;
   Options : Files.Types.Listing_Options)
   return Directory_Load_Result is
begin
   return Load_Directory_Filtered (Path, Classes, Options, null);
end Load_Directory;
