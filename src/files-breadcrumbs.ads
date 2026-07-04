with Ada.Containers.Vectors;

with Files.Types;

--  Pure breadcrumb segmentation for the clickable path bar.
--
--  A directory path is split into an ordered list of segments, each carrying a
--  display label (one path component, or "/" for the filesystem root) and the
--  full ancestor path up to and including that component. Clicking a segment
--  navigates to its ancestor path. The functions here touch neither the
--  filesystem nor any model state, so the interaction and rendering layers can
--  reuse them and the test suite can exercise them headless.
package Files.Breadcrumbs is
   subtype UString is Files.Types.UString;

   --  One clickable breadcrumb. Ancestor_Path is the absolute directory the
   --  segment navigates to; an empty Ancestor_Path marks a non-navigable
   --  elision marker inserted by Elide.
   type Segment is record
      Label         : UString;
      Ancestor_Path : UString;
   end record;

   package Segment_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Segment);

   --  The label shown for an elision marker inserted by Elide. It is path-like
   --  display data rather than a translatable catalog string.
   Ellipsis_Label : constant String := "...";

   --  Split an absolute directory path into ordered breadcrumb segments.
   --
   --  For "/home/user/files" the result is the three segments "home", "user",
   --  "files" whose ancestor paths are "/home", "/home/user", and
   --  "/home/user/files". The filesystem root is not emitted as its own
   --  segment. A trailing separator and repeated separators are ignored. An
   --  empty path yields an empty vector.
   --
   --  @param Path Absolute directory path to segment.
   --  @return Ordered breadcrumb segments from the first component to the leaf.
   function Segments
     (Path : String)
      return Segment_Vectors.Vector;

   --  Return whether a segment is a non-navigable elision marker.
   --
   --  @param Item Segment to test.
   --  @return True when Item was produced as an elision marker by Elide.
   function Is_Ellipsis
     (Item : Segment)
      return Boolean;

   --  Collapse leading segments when a path has more segments than fit.
   --
   --  When Items holds at most Max_Segments entries it is returned unchanged.
   --  Otherwise the root segment is kept, an ellipsis marker is inserted, and
   --  the trailing segments that fill the remaining budget are kept, so the
   --  root and the last few components stay visible. When Max_Segments is below
   --  three only the trailing segments are kept.
   --
   --  @param Items Full breadcrumb segments produced by Segments.
   --  @param Max_Segments Maximum number of segments the result may contain.
   --  @return Possibly elided breadcrumb segments.
   function Elide
     (Items        : Segment_Vectors.Vector;
      Max_Segments : Positive)
      return Segment_Vectors.Vector;

end Files.Breadcrumbs;
