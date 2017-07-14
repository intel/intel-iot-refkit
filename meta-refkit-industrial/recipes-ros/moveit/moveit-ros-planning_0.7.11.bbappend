FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI_append_df-refkit-industrial = "\
            file://0002-moveit_ros-planning-Use-TinyXML2-instead-of-TinyXML.patch \
            "
DEPENDS_remove_df-refkit-industrial = "libtinyxml"
DEPENDS_append_df-refkit-industrial = " libtinyxml2"
