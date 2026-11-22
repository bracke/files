with Files.Rendering.Geometry;

package body Files.Rendering.Layouts.Details is

   use Files.Rendering.Geometry;

   function Details_Header_Geometry
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive)
      return Details_Header_Layout
 is separate;

end Files.Rendering.Layouts.Details;
