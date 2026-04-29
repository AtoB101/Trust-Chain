const STORE_KEY='trustchain_ui_p0_state_v1';
function initState(){const d={buyer:{wallet:'0xA12...89F',token:'USDC',walletBalance:100,allowance:50,locked:30,active:24.5,reserved:5.5,settled:12.2,disputed:0,perCallLimit:0.05,dailyLimit:5,autoConfirm:0.01},services:[{id:'svc-001',name:'Price API',price:0.01,token:'USDC',status:'active'}],bills:[{id:'BILL-001',service:'Price API',seller:'MarketDataBot',amount:0.01,status:'Settled',createdAt:'2026-04-29 08:10'},{id:'BILL-002',service:'Risk Scan',seller:'SafeScan',amount:0.03,status:'Pending',createdAt:'2026-04-29 08:21'}],calls:[{time:'2026-04-29 08:21',agent:'Trading Agent',service:'Risk Scan',reason:'Token safety check',price:0.03,status:'Waiting settle'}],revenue:[{time:'2026-04-29 08:10',buyer:'0xA12...89F',service:'Price API',amount:0.01,status:'Settled'}]};localStorage.setItem(STORE_KEY,JSON.stringify(d));return d}
function getState(){const r=localStorage.getItem(STORE_KEY);if(!r)return initState();try{return JSON.parse(r)}catch{return initState()}}
function saveState(s){localStorage.setItem(STORE_KEY,JSON.stringify(s))}
function fmt(n,t){return `${Number(n).toFixed(2)} ${t}`}
window.tcUI={getState,saveState,fmt};
