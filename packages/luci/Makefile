include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-picoclaw
PKG_VERSION:=1.0.9
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/GennKann/luci-app-picoclaw.git
PKG_SOURCE_VERSION:=master

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-picoclaw
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI interface for PicoClaw
  DEPENDS:=+picoclaw
  PKGARCH:=all
endef

# Script để lấy giao diện từ source code
define Package/luci-app-picoclaw/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(CP) $(PKG_BUILD_DIR)/luci/* $(1)/usr/lib/lua/luci/
endef

$(eval $(call BuildPackage,luci-app-picoclaw))
