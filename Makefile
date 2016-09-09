

include $(TOPDIR)/rules.mk

PKG_NAME:=bcp38v6
PKG_VERSION:=0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0+

include $(INCLUDE_DIR)/package.mk

define Package/bcp38v6
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Routing and Redirection
  TITLE:=BCP38 compliance for IPv6
  URL:=https://github.com/zec/bcp38v6
  DEPENDS:=+ip6tables +ipset +lua +libubus-lua +libuci-lua
endef

define Package/bcp38v6/description
endef

define Package/bcp38v6/conffiles
/etc/config/bcp38v6
endef

